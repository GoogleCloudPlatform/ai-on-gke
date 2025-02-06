/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package main

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	ray "github.com/ray-project/kuberay/ray-operator/apis/ray/v1"
	utils "github.com/ray-project/kuberay/ray-operator/controllers/ray/utils"
	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	listersv1 "k8s.io/client-go/listers/core/v1"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/klog/v2"
)

// slice represents a TPU Pod Slice.
type slice struct {
	clusterName  string
	groupName    string
	namespace    string
	replicaIndex int
	numOfHosts   int32
}

// TPUWebhookServer is a KubeRay TPU webhook server instance.
type TPUWebhookServer struct {
	// podLister is used to query Pods from an informer cache.
	podLister    listersv1.PodLister
	cacheMutex   sync.Mutex
	wg           sync.WaitGroup
	waiting      int
	lastAdmitted string
}

// patch is a JSON patch describing mutate operation(s) for an incoming object.
type patch map[string]any

var (
	certPath        = "/etc/kuberay-tpu-webhook/tls/tls.crt"
	keyPath         = "/etc/kuberay-tpu-webhook/tls/tls.key"
	tpuResourceName = corev1.ResourceName("google.com/tpu")

	// headless svc will be of the form: {kuberay-cluster-name}-headless-worker-svc
	headlessServiceSuffix = "headless-worker-svc"

	// Flag arguments.
	BindAddr       string
	CACert         string
	KubeConfigPath string
	ServerCert     string
	ServerKey      string
)

func NewTPUWebhookServer(podLister listersv1.PodLister) *TPUWebhookServer {
	return &TPUWebhookServer{
		podLister: podLister,
	}
}

// Mutate handles http Request for Pod creation and writes a response
func (t *TPUWebhookServer) Mutate(w http.ResponseWriter, r *http.Request) {
	t.cacheMutex.Lock()
	defer t.cacheMutex.Unlock()

	admissionReview := &admissionv1.AdmissionReview{}
	if err := json.NewDecoder(r.Body).Decode(admissionReview); err != nil {
		http.Error(w, "Error decoding request body", http.StatusBadRequest)
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	if admissionReview.Request == nil || admissionReview.Request.Kind.Kind != "Pod" {
		http.Error(w, "Invalid Kind", http.StatusBadRequest)
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	klog.V(0).InfoS("Mutate", "Received review for Pod creation: %s", admissionReview.Request.Name)
	response, err := t.mutatePod(admissionReview)
	if err != nil {
		klog.Errorf("Failed to mutate Pod: %s", err)
		http.Error(w, "Failed to mutate Pod", http.StatusForbidden)
		w.WriteHeader(http.StatusForbidden)
		return
	}
	admissionReview.Response = response
	responseBytes, err := json.Marshal(admissionReview)
	if err != nil {
		klog.Errorf("Failed to encode response: %s", err)
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	fmt.Fprint(w, string(responseBytes))
}

// Validate handles http Request for RayCluster creation and writes a response
func (t *TPUWebhookServer) Validate(w http.ResponseWriter, r *http.Request) {
	admissionReview := &admissionv1.AdmissionReview{}
	if err := json.NewDecoder(r.Body).Decode(admissionReview); err != nil {
		http.Error(w, "Error decoding request body", http.StatusBadRequest)
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	if admissionReview.Request == nil || admissionReview.Request.Kind.Kind != "RayCluster" {
		http.Error(w, "Invalid Kind", http.StatusBadRequest)
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	klog.V(0).InfoS("Validate", "Received review for RayCluster creation: %s", admissionReview.Request.Name)
	response, err := validateRayCluster(admissionReview)
	if err != nil {
		klog.Errorf("Failed to validate RayCluster: %s", err)
		http.Error(w, "Failed to validate RayCluster", http.StatusForbidden)
		w.WriteHeader(http.StatusForbidden)
		return
	}
	admissionReview.Response = response
	responseBytes, err := json.Marshal(admissionReview)
	if err != nil {
		klog.Errorf("Failed to encode response: %s", err)
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	fmt.Fprint(w, string(responseBytes))
}

// printSliceToWorkerIds logs sliceToWorkerIDs contents for debugging
func printSliceToWorkerIds(sliceToWorkerIDs map[slice][]int) {
	for slice, workerList := range sliceToWorkerIDs {
		klog.V(1).InfoS("printSliceToWorkerIds", "RayCluster", slice.namespace+"/"+slice.clusterName, "Worker Group", slice.groupName)
		for _, workerID := range workerList {
			klog.V(1).InfoS("printSliceToWorkerIds", "RayCluster", slice.namespace+"/"+slice.clusterName, "Worker ID", workerID)
		}
	}
}

// containerRequestingTPUs returns whether containers are requesting TPU resources
func containerRequestingTPUs(containers ...corev1.Container) bool {
	for _, container := range containers {
		if l := container.Resources.Limits; l != nil {
			if resource := l[tpuResourceName]; !resource.IsZero() {
				return true
			}
		}
		if r := container.Resources.Requests; r != nil {
			if resource := r[tpuResourceName]; !resource.IsZero() {
				return true
			}
		}
	}
	return false
}

// getNumTPUChipsRequested returns `google.com/TPU` Resource request value for the container
// this indicates the number of TPU chips for the container to use
func getNumTPUChipsRequested(containers ...corev1.Container) int64 {
	tpuLimit := int64(0)
	tpuRequest := int64(0)
	for _, container := range containers {
		if l := container.Resources.Limits; l != nil {
			if resource := l[tpuResourceName]; !resource.IsZero() {
				tpuLimit = resource.Value()
			}
		}
		if r := container.Resources.Requests; r != nil {
			if resource := r[tpuResourceName]; !resource.IsZero() {
				tpuRequest = resource.Value()
			}
		} else {
			// default to limit if request is ommitted
			tpuRequest = tpuLimit
		}
	}
	return min(tpuLimit, tpuRequest)
}

// getNumTPUHostsFromTopology returns number of TPU VM hosts in Pod Slice specified by gke-tpu-topology Pod nodeSelector
func getNumTPUHostsFromTopology(clusterName string, groupName string, namespace string, topology string, chipsPerHost int64) (int32, error) {
	if topology == "" {
		return 0, errors.New("TPU topology not specified")
	}
	topologyVals := strings.Split(topology, "x")
	chips := 1
	for i := 0; i < len(topologyVals); i++ {
		dim, err := strconv.Atoi(topologyVals[i])
		if err != nil {
			klog.ErrorS(err, "getNumTPUHostsFromTopology", "RayCluster", namespace+"/"+clusterName, "Worker Group", groupName, "gke-tpu-topology", topology)
			return 0, err
		}
		chips *= dim
	}
	// calculate the # of VMs using # of chips per host
	hosts := max(int32(chips)/int32(chipsPerHost), 1)
	klog.V(1).InfoS("getNumTPUHostsFromTopology", "RayCluster", namespace+"/"+clusterName, "Worker Group", groupName, "topology", topology, "chips", chips, "hosts", hosts)
	return hosts, nil
}

// extractRayCluster returns RayCluster unmarshalled from an admission request
func extractRayCluster(admissionReview *admissionv1.AdmissionReview) (*ray.RayCluster, error) {
	if admissionReview.Request.Kind.Kind != "RayCluster" {
		return nil, fmt.Errorf("Expected RayCluster but got %s", admissionReview.Request.Kind.Kind)
	}

	rayCluster := ray.RayCluster{}
	if err := json.Unmarshal(admissionReview.Request.Object.Raw, &rayCluster); err != nil {
		return nil, err
	}

	return &rayCluster, nil
}

// generateHeadlessServiceName returns the expected TPU headless service name for a RayCluster
func generateHeadlessServiceName(clusterName string) string {
	serviceName := fmt.Sprintf("%s-%s", clusterName, headlessServiceSuffix)

	// Apply the same truncation as in the RayCluster controller when generating the headless service
	// name. This is to maintain the up-to 63 char compatibility guarantee for hostnames (RFC 1123).
	return utils.CheckName(serviceName)
}

// genDNSHostnames returns list of DNS hostnames for TPU VM hosts as a string
func genDNSHostnames(numOfHosts int32, groupName string, clusterName string, namespace string, replicaIndex int) (string, error) {
	if numOfHosts == 0 {
		err := errors.New("workerGroupSpec NumOfHosts not set")
		return "", err
	}
	headlessServiceName := generateHeadlessServiceName(clusterName)
	hostNames := make([]string, numOfHosts)
	// Host names will be of the form {WORKER_GROUP_NAME}-{REPLICA_INDEX}-{HOST_INDEX}.{CLUSTER_NAME}-headless-worker-svc
	for j := 0; j < int(numOfHosts); j++ {
		hostNames[j] = fmt.Sprintf("%s-%d-%d.%s", groupName, replicaIndex, j, headlessServiceName)
	}
	klog.V(1).InfoS("genDNSHostnames", "RayCluster", namespace+"/"+clusterName, "NumOfHosts", numOfHosts, "Replica Index", replicaIndex)
	return strings.Join(hostNames, ","), nil
}

// injectHostnames injects subdomain and TPU_WORKER_HOSTNAMES into a Pod for TPU multi-host initialization
func injectHostnames(clusterName string, hostNames string, envPath string, container corev1.Container, patches *[]patch) {
	subdomainPatch, hostNamesPatch := patch{"op": "add"}, patch{"op": "add"}
	subdomainPath := "/spec/subdomain"
	tpuWorkerHostNames := corev1.EnvVar{
		Name:  "TPU_WORKER_HOSTNAMES",
		Value: hostNames,
	}
	subdomainPatch["path"] = subdomainPath
	subdomainPatch["value"] = generateHeadlessServiceName(clusterName)
	// create new EnvVar array if container.Env is empty, and append hostnames if not
	if len(container.Env) == 0 {
		hostNamesPatch["path"] = envPath
		hostNamesPatch["value"] = []corev1.EnvVar{tpuWorkerHostNames}
	} else {
		hostNamesPatch["path"] = fmt.Sprintf("%s/-", envPath)
		hostNamesPatch["value"] = tpuWorkerHostNames
	}
	*patches = append(*patches, subdomainPatch, hostNamesPatch)
}

// injectReplicaLabel injects replicaIndex label into a Pod for TPU Pod scheduling and Ray multi-host autoscaling
func injectReplicaLabel(clusterName string, namespace string, replicaIndex int, workerGroupName string, patches *[]patch) {
	labelPatch := patch{"op": "replace"}
	labelPath := "/metadata/labels/replicaIndex"
	replicaLabelValue := workerGroupName + "-" + strconv.Itoa(replicaIndex)

	klog.V(1).InfoS("injectReplicaLabel", "RayCluster", namespace+"/"+clusterName, "replicaIndex", replicaLabelValue)

	labelPatch["path"] = labelPath
	labelPatch["value"] = replicaLabelValue

	*patches = append(*patches, labelPatch)
}

// injectPodAffinity injects pod affinity and anti-affinity scheduling constraints using replicaIndex label
func injectPodAffinity(pod *corev1.Pod, replicaIndex int, workerGroupName string, patches *[]patch) {
	key := "replicaIndex"
	value := workerGroupName + "-" + strconv.Itoa(replicaIndex)
	topologyKey := "cloud.google.com/gke-nodepool"
	clusterName := pod.Labels["ray.io/cluster"]
	namespace := pod.Namespace

	klog.V(1).InfoS("injectPodAffinity", "RayCluster", namespace+"/"+clusterName, "podAffinity match label", value)

	// construct affinity value to inject - schedule pods with the same replicaIndex together
	podAffinityPatch := patch{"op": "add"}

	affinitySelectorRequirement := metav1.LabelSelectorRequirement{Key: key, Operator: metav1.LabelSelectorOpIn, Values: []string{value}}
	affinityMatchExpressions := []metav1.LabelSelectorRequirement{affinitySelectorRequirement}
	affinityLabelSelector := metav1.LabelSelector{MatchExpressions: affinityMatchExpressions}
	podAffinityTerms := []corev1.PodAffinityTerm{corev1.PodAffinityTerm{LabelSelector: &affinityLabelSelector, TopologyKey: topologyKey}}
	podAffinity := corev1.PodAffinity{RequiredDuringSchedulingIgnoredDuringExecution: podAffinityTerms}

	if pod.Spec.Affinity != nil {
		podAffinityPatch["path"] = "/spec/affinity/podAffinity"
		podAffinityPatch["value"] = podAffinity
	} else {
		podAffinityPatch["path"] = "/spec/affinity"
		podAffinityPatch["value"] = corev1.Affinity{PodAffinity: &podAffinity}
	}

	*patches = append(*patches, podAffinityPatch)
}

// checkWorkersMatchTopology returns whether the # of Ray TPU worker pods equals the # of hosts defined in the topology key
func checkWorkersMatchTopology(clusterName string, namespace string, workerGroupSpec ray.WorkerGroupSpec) (bool, error) {
	klog.V(1).InfoS("checkWorkersMatchTopology", "RayCluster", namespace+"/"+clusterName, "workerGroup", workerGroupSpec.GroupName)
	numHosts := workerGroupSpec.NumOfHosts // 1 TPU VM host -> 1 Ray worker pod
	if numHosts == 0 {
		return false, errors.New("workerGroupSpec NumOfHosts not set")
	}
	groupName := workerGroupSpec.GroupName
	containers := workerGroupSpec.Template.Spec.Containers
	if len(containers) == 0 {
		return false, errors.New("Container path not specified")
	}
	if containerRequestingTPUs(containers...) {
		topology := workerGroupSpec.Template.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
		klog.V(1).InfoS("checkWorkersMatchTopology", "RayCluster", namespace+"/"+clusterName, "topology", topology, "NumOfHosts", numHosts)
		if topology == "" {
			err := errors.New("TPU topology not specified")
			klog.ErrorS(err, "checkWorkersMatchTopology", "RayCluster", namespace+"/"+clusterName, "gke-tpu-topology", topology)
			return false, err
		}
		chipsPerHost := getNumTPUChipsRequested(containers...)
		if chipsPerHost == 0 {
			err := errors.New("Container does not set TPU limits")
			klog.ErrorS(err, "checkWorkersMatchTopology", "RayCluster", namespace+"/"+clusterName, "gke-tpu-topology", topology)
			return false, err
		}
		expectedHosts, err := getNumTPUHostsFromTopology(clusterName, groupName, namespace, topology, chipsPerHost)
		if err != nil {
			return false, err
		}

		if expectedHosts != numHosts {
			return false, nil
		}
	}
	return true, nil
}

// validateRayCluster returns an Admission Response after checking Ray worker groups match TPU scheduling constraints
func validateRayCluster(admissionReview *admissionv1.AdmissionReview) (*admissionv1.AdmissionResponse, error) {
	raycluster, err := extractRayCluster(admissionReview)
	if err != nil {
		return nil, err
	}

	admit := true
	status := "Success"
	message := ""
	clusterName := raycluster.Name
	namespace := raycluster.Namespace
	klog.V(1).InfoS("validateRayCluster", "RayCluster", namespace+"/"+clusterName)
	workerGroupSpecs := raycluster.Spec.WorkerGroupSpecs
	for i := 0; i < len(workerGroupSpecs); i++ {
		workerGroupSpec := workerGroupSpecs[i]
		workerGroupContainers := workerGroupSpec.Template.Spec.Containers
		if len(workerGroupContainers) != 0 && !containerRequestingTPUs(workerGroupContainers...) {
			// pass through if no TPUs are requested
			continue
		}
		// validate NumOfHosts for worker group matches topology nodeSelector
		workersMatchTopology, err := checkWorkersMatchTopology(clusterName, namespace, workerGroupSpec)
		if err != nil {
			return nil, err
		}

		if !workersMatchTopology {
			admit = false
			status = "Failure"
			message = "Number of workers in worker group not equal to specified topology"
			break
		}
	}

	// Create AdmissionResponse
	admissionResponse := &admissionv1.AdmissionResponse{
		UID:     admissionReview.Request.UID,
		Allowed: admit,
		Result: &metav1.Status{
			Status:  status,
			Message: message,
		},
	}
	return admissionResponse, nil
}

// getEnvironmentVariable returns value associated with a given Container environment variable
func getEnvironmentVariable(varName string, container corev1.Container) string {
	if container.Env != nil && len(container.Env) > 0 {
		for _, envVar := range container.Env {
			if envVar.Name == varName {
				return envVar.Value
			}
		}
	}
	return ""
}

// getReplicaIndex returns the next lowest-index Pod Slice (worker group replica) to assign a Pod to in the RayCluster
// there are three possible cases here:
//  1. sliceToWorkerIDs is empty, this is the first pod the webhook intercepts
//     - assign this pod to replica 0
//  2. The Pod Slice exists in sliceToWorkerIDs, but has # created workers < NumOfHosts
//     - assign this pod to the lowest index replica with # created workers < NumOfHosts
//     pods to the same replica
//  3. sliceToWorkerIDs isn't empty, but all slices have # workers == NumOfHosts
//     - this occurs when the pod we intercept is the first pod of a different slice in the cluster
//     - we keep track of how many replicas of the same worker group have been added to sliceToWorkerIDs
//     so far, and assign this pod to the next integer replicaIndex
func getReplicaIndex(sliceToWorkerIDs map[slice][]int, clusterName string, groupName string, namespace string) int {
	// first pod created in cluster
	if len(sliceToWorkerIDs) == 0 {
		return 0
	}
	nextLowestId := math.MaxInt32
	numReplicas := 0 // tracks # of replicas in worker group created so far
	for slice, workerList := range sliceToWorkerIDs {
		if slice.clusterName == clusterName && slice.groupName == groupName && slice.namespace == namespace {
			numReplicas++
			createdPods := len(workerList)
			if createdPods < int(slice.numOfHosts) {
				if slice.replicaIndex < nextLowestId {
					nextLowestId = slice.replicaIndex
				}
			}
		}
	}
	// first pod of new slice in cluster
	if nextLowestId == math.MaxInt32 {
		nextLowestId = numReplicas
	}
	klog.V(1).InfoS("getReplicaIndex", "RayCluster", namespace+"/"+clusterName, "Worker Group", groupName, "Replica Index", nextLowestId)
	return nextLowestId
}

// getNextWorkerID returns the next lowest TPU_WORKER_ID in the Pod Slice
func getNextWorkerID(sliceToWorkerIDs map[slice][]int, podSlice slice, namespace string, replicaIndex int) (int, error) {
	tpuWorkerID := 0 // defaults to 0 (first Pod in slice)
	if len(sliceToWorkerIDs) == 0 || len(sliceToWorkerIDs[podSlice]) == 0 {
		return tpuWorkerID, nil
	}
	sort.Ints(sliceToWorkerIDs[podSlice])
	// iterate through existing workers and get the next lowest, unused ID
	lastID := 0
	for index, workerID := range sliceToWorkerIDs[podSlice] {
		// check for incorrect assignment of IDs
		if index == 0 {
			lastID = workerID
		} else if workerID == lastID {
			return 0, errors.New("Identical TPU_WORKER_ID assigned to multiple TPU workers in slice")
		}
		// get the next lowest, valid TPU_WORKER_ID
		if workerID != tpuWorkerID {
			break
		}
		lastID = workerID
		tpuWorkerID++
	}
	klog.V(1).InfoS("getNextWorkerID", "RayCluster", namespace+"/"+podSlice.clusterName, "Worker Group", podSlice.groupName, "replicaIndex", replicaIndex, "TPU_WORKER_ID", tpuWorkerID)
	return tpuWorkerID, nil
}

// getSliceToWorkerIDs returns a mapping representing the current RayCluster state of TPU pods using a PodLister
func (t *TPUWebhookServer) getSliceToWorkerIDs(clusterName string, groupName string, namespace string, numOfHosts int32) (map[slice][]int, error) {
	sliceToWorkerIDs := make(map[slice][]int)

	// we only care about workers in the same RayCluster and worker group when assigning IDs
	podsInGroup, err := t.podLister.Pods(namespace).List(labels.SelectorFromSet(labels.Set{"ray.io/cluster": clusterName, "ray.io/group": groupName}))
	if err != nil {
		return nil, err
	}

	if podsInGroup == nil {
		// return an empty mapping if no Pods with 'ray.io/group' label found
		return sliceToWorkerIDs, nil
	}
	klog.V(1).InfoS("getSliceToWorkerIDs", "RayCluster", namespace+"/"+clusterName, "# Pods in Group", len(podsInGroup))
	for _, existingPod := range podsInGroup {
		if existingPod.DeletionTimestamp != nil {
			continue
		}
		existingNamespace := existingPod.Namespace
		// check that Pods are in the same namespace
		if namespace != existingNamespace {
			continue
		}

		if !containerRequestingTPUs(existingPod.Spec.Containers...) {
			// Pod does not request TPUs, 'ray.io/group' is not a TPU worker group
			return sliceToWorkerIDs, nil
		}
		replicaIndexLabel := existingPod.Labels["replicaIndex"]
		if replicaIndexLabel == "" {
			// Pod has not been intercepted by the KubeRay TPU webhook yet
			continue
		}
		replicaIndexLabelValues := strings.Split(replicaIndexLabel, "-")
		existingReplicaIndex, _ := strconv.Atoi(replicaIndexLabelValues[len(replicaIndexLabelValues)-1])
		existingWorkerID := -1
		for _, container := range existingPod.Spec.Containers {
			if !containerRequestingTPUs(container) {
				continue
			}

			tpuWorkerIDEnvVar := getEnvironmentVariable("TPU_WORKER_ID", container)
			tempVar, err := strconv.Atoi(tpuWorkerIDEnvVar)
			if err != nil {
				klog.ErrorS(err, "getSliceToWorkerIDs", "RayCluster", namespace+"/"+clusterName, "TPU_WORKER_ID", tpuWorkerIDEnvVar)
				continue
			}
			existingWorkerID = tempVar
			break
		}
		if existingPod.Status.Phase == "Running" && existingWorkerID == -1 {
			return nil, errors.New("existing TPU worker missing TPU_WORKER_ID")
		}
		if existingWorkerID != -1 {
			// Pod has been intercepted by the webhook
			podSlice := slice{clusterName, groupName, namespace, existingReplicaIndex, numOfHosts}
			if sliceToWorkerIDs[podSlice] == nil {
				sliceToWorkerIDs[podSlice] = []int{existingWorkerID}
			} else {
				sliceToWorkerIDs[podSlice] = append(sliceToWorkerIDs[podSlice], existingWorkerID)
			}
			klog.V(1).InfoS("getSliceToWorkerIDs", "RayCluster", namespace+"/"+clusterName, "ReplicaIndex", existingReplicaIndex, "TPU_WORKER_ID", existingWorkerID)

		}
	}
	return sliceToWorkerIDs, nil
}

// extractPod returns a Pod unmarshalled from an Admission Request
func extractPod(admissionReview *admissionv1.AdmissionReview) (*corev1.Pod, error) {
	if admissionReview.Request.Kind.Kind != "Pod" {
		return nil, fmt.Errorf("Expected Pod but got %s", admissionReview.Request.Kind.Kind)
	}

	pod := corev1.Pod{}
	if admissionReview.Request.Operation == "CREATE" {
		if err := json.Unmarshal(admissionReview.Request.Object.Raw, &pod); err != nil {
			return nil, err
		}
	}

	return &pod, nil
}

// waitTimeout helper function to sync.WaitGroup Wait() or timeout
func waitTimeout(wait *sync.WaitGroup, timeout time.Duration) bool {
	waitChan := make(chan struct{})
	go func() {
		defer close(waitChan)
		wait.Wait()
	}()
	select {
	case <-waitChan:
		return true // Wait() returned
	case <-time.After(timeout):
		return false // Request timed out
	}
}

// mutatePod returns an Admission Response after injecting TPU related fields to a given Pod
func (t *TPUWebhookServer) mutatePod(admissionReview *admissionv1.AdmissionReview) (*admissionv1.AdmissionResponse, error) {
	pod, err := extractPod(admissionReview)
	if err != nil {
		return nil, err
	}

	var patches []patch
	admissionResponse := &admissionv1.AdmissionResponse{
		UID:     admissionReview.Request.UID,
		Allowed: true,
	}

	containers := pod.Spec.Containers
	if containers == nil {
		return nil, errors.New("Container path not specified")
	}
	if !containerRequestingTPUs(containers...) {
		// if no TPUs are requested, simply admit the Pod
		return admissionResponse, nil
	}

	// ray operator only sets GenerateName field - doesn't include random suffix until after admission request
	// use mapping of {cluster name, group name, replicaIndex} -> workers to extract next TPU_WORKER_ID
	clusterName := pod.Labels["ray.io/cluster"]
	if clusterName == "" {
		return nil, errors.New("Ray Pod created by KubeRay missing RayCluster label")
	}
	groupName := pod.Labels["ray.io/group"]
	if groupName == "" {
		return nil, errors.New("Ray Pod created by KubeRay missing Group label")
	}
	namespace := pod.Namespace
	topology := pod.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
	if topology == "" {
		return nil, errors.New("Ray Pod created by KubeRay missing TPU topology nodeSelector")
	}
	// assign worker to the next unique ID in the Pod Slice and update map
	chipsPerHost := getNumTPUChipsRequested(containers...)
	numOfHosts, _ := getNumTPUHostsFromTopology(clusterName, groupName, namespace, topology, chipsPerHost) // ignore error here because topology may not be set yet

	// Wait for PodInformer cache to update from previous requests or timeout
	if waitTimeout(&t.wg, time.Second*1) {
		klog.V(1).Info("MutatePod", "PodInformer AddFunc called for prior admission request")
	} else {
		klog.V(1).Info("MutatePod", "Timed out waiting for PodInformer AddFunc")
	}
	// Add 1 to the WaitGroup to represent the pending Pod to the cache
	defer t.wg.Add(1)
	t.waiting += 1

	// query k8s client to populate sliceToWorkerIDs to then calculate the next TPU_WORKER_ID and replicaIndex
	sliceToWorkerIDs, err := t.getSliceToWorkerIDs(clusterName, groupName, namespace, numOfHosts)
	if err != nil {
		return nil, err
	}
	replicaIndex := getReplicaIndex(sliceToWorkerIDs, clusterName, groupName, namespace)
	podSlice := slice{clusterName, groupName, namespace, replicaIndex, numOfHosts}
	tpuWorkerID, err := getNextWorkerID(sliceToWorkerIDs, podSlice, namespace, replicaIndex) // defaults to 0 for single-host
	if err != nil {
		return nil, err
	}
	// set the unique identifier for the last admitted Pod by this TPUWebhookServer
	t.lastAdmitted = fmt.Sprintf("%s-%s-%d-%d", namespace, clusterName, replicaIndex, tpuWorkerID)

	// inject replica index label
	injectReplicaLabel(clusterName, namespace, replicaIndex, groupName, &patches)

	if numOfHosts > 1 {
		// inject hostname into pod spec for DNS records
		hostname := fmt.Sprintf(groupName+"-%d-%d", replicaIndex, tpuWorkerID)
		klog.V(1).InfoS("mutatePod", "RayCluster", namespace+"/"+clusterName, "hostname", hostname)
		hostnamePatch := patch{"op": "add"}
		hostnamePatch["path"] = "/spec/hostname"
		hostnamePatch["value"] = hostname
		patches = append(patches, hostnamePatch)

		// inject pod affinity/anti-affinity for scheduling
		injectPodAffinity(pod, replicaIndex, groupName, &patches)
	}

	// inject all environment variables into the container requesting TPUs
	for i := 0; i < len(containers); i++ {
		container := containers[i]
		if containerRequestingTPUs(container) {
			path := fmt.Sprintf("/spec/containers/%d/env", i)
			if numOfHosts > 1 {
				// inject TPU_WORKER_HOSTNAMES
				hostnames, err := genDNSHostnames(numOfHosts, groupName, clusterName, namespace, replicaIndex)
				if err != nil {
					return nil, err
				}
				klog.V(1).InfoS("mutatePod", "RayCluster", namespace+"/"+clusterName, "TPU_WORKER_HOSTNAMES", hostnames)
				klog.V(1).InfoS("mutatePod", "RayCluster", namespace+"/"+clusterName, "subdomain", generateHeadlessServiceName(clusterName))
				injectHostnames(clusterName, hostnames, path, container, &patches)
			}
			// inject TPU_WORKER_ID
			if getEnvironmentVariable("TPU_WORKER_ID", container) == "" {
				klog.V(1).InfoS("mutatePod", "RayCluster", namespace+"/"+clusterName, "TPU_WORKER_ID", tpuWorkerID, "Replica Index", replicaIndex)
				workerID := corev1.EnvVar{
					Name:  "TPU_WORKER_ID",
					Value: fmt.Sprint(tpuWorkerID),
				}
				idPatch := patch{"op": "add"}
				// create new EnvVar array if container.Env is empty, and append new EnvVars if not
				if len(container.Env) == 0 {
					idPatch["path"] = path
					idPatch["value"] = []corev1.EnvVar{workerID}
				} else {
					idPatch["path"] = fmt.Sprintf("%s/-", path)
					idPatch["value"] = workerID
				}
				patches = append(patches, idPatch)
			}
			// inject TPU_NAME
			if getEnvironmentVariable("TPU_NAME", container) == "" {
				tpuNameValue := fmt.Sprintf("%s-%d", groupName, replicaIndex)
				klog.V(1).InfoS("mutatePod", "RayCluster", namespace+"/"+clusterName, "TPU_NAME", tpuNameValue, "Replica Index", replicaIndex)
				tpuName := corev1.EnvVar{
					Name:  "TPU_NAME",
					Value: tpuNameValue,
				}
				namePatch := patch{"op": "add"}
				// create new EnvVar array if container.Env is empty, and append new EnvVars if not
				if len(container.Env) == 0 {
					namePatch["path"] = path
					namePatch["value"] = []corev1.EnvVar{tpuName}
				} else {
					namePatch["path"] = fmt.Sprintf("%s/-", path)
					namePatch["value"] = tpuName
				}
				patches = append(patches, namePatch)
			}
		}
	}

	patchBytes, err := json.Marshal(patches)
	if err != nil {
		return nil, err
	}

	admissionResponse.Patch = patchBytes
	admissionResponse.PatchType = func() *admissionv1.PatchType {
		pt := admissionv1.PatchTypeJSONPatch
		return &pt
	}()
	return admissionResponse, nil
}

func writeCertfile(filename string, encodedData string) error {
	data, err := base64.StdEncoding.DecodeString(encodedData)
	if err != nil {
		return err
	}
	_ = os.MkdirAll(filepath.Dir(filename), 0755)
	return os.WriteFile(filename, data, 0644)
}

func init() {
	flag.StringVar(&BindAddr, "bind-address", ":443", "Address to bind HTTPS service to")
	flag.StringVar(&CACert, "ca-cert", "", "base64-encoded root certificate for TLS")
	flag.StringVar(&ServerCert, "server-cert", "", "base64-encoded server certificate for TLS")
	flag.StringVar(&ServerKey, "server-key", "", "base64-encoded server key for TLS")
	flag.StringVar(&KubeConfigPath, "kube-config-path", "", "Kubernetes config path for k8s client")

	// set klog verbosity level
	klog.InitFlags(nil)
}

// isLastAdmittedPod returns True if Pod matches the last Pod admitted by the webhook server
func (t *TPUWebhookServer) isLastAdmittedPod(pod *corev1.Pod) (bool, error) {
	if pod.Spec.Containers == nil || !containerRequestingTPUs(pod.Spec.Containers...) {
		// Pod does not use TPUs
		return false, nil
	}
	replicaIndex := pod.Labels["replicaIndex"]
	if replicaIndex == "" {
		// Pod was not mutated by the webhook
		return false, nil
	}
	clusterName := pod.Labels["ray.io/cluster"]
	if clusterName == "" {
		return false, errors.New("Ray Pod created by KubeRay missing RayCluster label")
	}
	namespace := pod.Namespace
	for _, container := range pod.Spec.Containers {
		if !containerRequestingTPUs(container) {
			// Skip to the next container
			continue
		}
		tpuWorkerID := getEnvironmentVariable("TPU_WORKER_ID", container)
		if tpuWorkerID == "" {
			// TPU pod was not intercepted by the webhook
			return false, nil
		}
		uniquePodID := fmt.Sprintf("%s-%s-%s-%s", namespace, clusterName, replicaIndex, tpuWorkerID)
		if uniquePodID == t.lastAdmitted {
			// Pod matches the last TPU worker Pod intercepted by the webhook server
			return true, nil
		}
	}
	return false, nil
}

// addPod allows next goroutine to start once the webhook PodInformer cache updates
func (t *TPUWebhookServer) addPod(obj interface{}) {
	pod := obj.(*corev1.Pod)
	klog.V(1).InfoS("addPod", "Pod", pod.Namespace+"/"+pod.Name, "Time", time.Now())

	if t.lastAdmitted == "" {
		// There is not a pending TPU worker Pod to the informer cache, unblock if waiting and return
		for t.waiting > 0 {
			t.wg.Done()
			t.waiting -= 1
		}
		return
	}
	if t.waiting == 0 {
		// Webhook is not waiting, no-op
		return
	}
	// Check if Pod in cache is the last admitted TPU Pod
	isLastAdmitted, err := t.isLastAdmittedPod(pod)
	if err != nil {
		klog.Errorf("Invalid addPod: %s", err)
		return
	}
	if isLastAdmitted {
		// Informer cache has been updated, unblock the next Mutate call
		t.wg.Done()
		t.waiting -= 1
	}
}

func main() {
	flag.Parse()

	// use in-cluster config if kubeConfig path is not passed as a flag
	var client *kubernetes.Clientset
	if KubeConfigPath == "" {
		config, err := rest.InClusterConfig()
		if err != nil {
			panic(err)
		}
		client = kubernetes.NewForConfigOrDie(config)
	} else {
		config, err := clientcmd.BuildConfigFromFlags("", KubeConfigPath)
		if err != nil {
			panic(err)
		}
		client = kubernetes.NewForConfigOrDie(config)
	}

	// instantiate PodInformer for Ray worker pods in the GKE cluster
	tweakListOptionsFunc := func(options *metav1.ListOptions) {
		options.LabelSelector = "ray.io/node-type=worker,app.kubernetes.io/created-by=kuberay-operator"
	}
	factory := informers.NewFilteredSharedInformerFactory(client, 1*time.Minute, metav1.NamespaceAll, tweakListOptionsFunc)
	podInformer := factory.Core().V1().Pods().Informer()

	// start the PodInformer and wait for cache sync
	stopCh := make(chan struct{})
	factory.Start(stopCh)
	factory.WaitForCacheSync(stopCh)

	if !cache.WaitForCacheSync(stopCh, podInformer.HasSynced) {
		klog.Fatal("Timed out waiting for PodInformer to sync")
	}

	podLister := factory.Core().V1().Pods().Lister()

	if podLister == nil {
		klog.Fatal("Failed to initialize Pod Lister")
	}

	// close the PodInformer on exit
	defer close(stopCh)

	tpuWebhookServer := NewTPUWebhookServer(podLister)

	// Add custom event handler for Pod creation
	podInformer.AddEventHandler(
		cache.ResourceEventHandlerFuncs{
			AddFunc: tpuWebhookServer.addPod,
		},
	)

	mux := http.NewServeMux()

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, "kuberay-tpu-webhook")
	})

	mux.HandleFunc("/mutate", tpuWebhookServer.Mutate)

	mux.HandleFunc("/validate", tpuWebhookServer.Validate)

	srv := &http.Server{
		Addr:    BindAddr,
		Handler: mux,
	}

	if ServerCert != "" && ServerKey != "" {
		if err := writeCertfile(certPath, ServerCert); err != nil {
			klog.Fatalf("write server cert: %v", err)
		}
		if err := writeCertfile(keyPath, ServerKey); err != nil {
			klog.Fatalf("write server key: %v", err)
		}
	}

	if err := srv.ListenAndServeTLS(certPath, keyPath); err != nil {
		if err == http.ErrServerClosed {
			klog.V(0).Info("Server closed")
			return
		}
		klog.Error("Failed to start server")
	}
}
