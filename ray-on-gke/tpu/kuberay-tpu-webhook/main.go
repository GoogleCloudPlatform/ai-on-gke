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
	"strconv"
	"strings"

	ray "github.com/ray-project/kuberay/ray-operator/apis/ray/v1"
	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/klog/v2"
)

// our representation of a pod slice
type slice struct {
	clusterName  string
	groupName    string
	namespace    string
	replicaIndex int
	numOfHosts   int32
}

// our representation of a worker pod
type worker struct {
	workerIndex  int  // TPU_WORKER_ID
	replicaIndex int  // index of replica worker belongs to
	isCreated    bool // true = pod has been created, false = pod deleted / hasn't been created yet
}

// JSON patch describing mutate operation(s) for incoming object
type patch map[string]any

var (
	certPath        = "/etc/kuberay-tpu-webhook/tls/tls.crt"
	keyPath         = "/etc/kuberay-tpu-webhook/tls/tls.key"
	tpuResourceName = corev1.ResourceName("google.com/tpu")

	// headless svc will be of the form: {kuberay-cluster-name}-headless-worker-svc
	headlessServiceSuffix = "headless-worker-svc"

	// map of pod slices to workers in the slice
	sliceToWorkers map[slice][]worker

	// Flag arguments.
	BindAddr   string
	CACert     string
	ServerCert string
	ServerKey  string
)

// check if containers are requesting TPU resources
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

// returns `google.com/TPU` Resource request value for the container
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

// unmarshal raycluster from admission request
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

func genDNSHostnames(numOfHosts int32, groupName string, clusterName string, namespace string, replicaIndex int) (string, error) {
	if numOfHosts == 0 {
		err := errors.New("workerGroupSpec NumOfHosts not set")
		return "", err
	}
	hostNames := make([]string, numOfHosts)
	// Host names will be of the form {WORKER_GROUP_NAME}-{REPLICA_INDEX}-{HOST_INDEX}.headless-worker-svc
	for j := 0; j < int(numOfHosts); j++ {
		hostNames[j] = fmt.Sprintf("%s-%d-%d.%s-%s", groupName, replicaIndex, j, clusterName, headlessServiceSuffix)
	}
	klog.V(1).InfoS("genDNSHostnames", "RayCluster", namespace+"/"+clusterName, "NumOfHosts", numOfHosts, "Replica Index", replicaIndex)
	return strings.Join(hostNames, ","), nil
}

// inject subdomain and TPU_WORKER_HOSTNAMES into pods for TPU multi-host initialization
func injectHostnames(clusterName string, hostNames string, envPath string, container corev1.Container, patches *[]patch) {
	subdomainPatch, hostNamesPatch := patch{"op": "add"}, patch{"op": "add"}
	subdomainPath := "/spec/subdomain"
	tpuWorkerHostNames := corev1.EnvVar{
		Name:  "TPU_WORKER_HOSTNAMES",
		Value: hostNames,
	}
	subdomainPatch["path"] = subdomainPath
	subdomainPatch["value"] = fmt.Sprintf("%s-%s", clusterName, headlessServiceSuffix)
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

func injectReplicaLabel(clusterName string, namespace string, replicaIndex int, workerGroupName string, patches *[]patch) {
	labelPatch := patch{"op": "replace"}
	labelPath := "/metadata/labels/replicaIndex"
	replicaLabelValue := workerGroupName + "-" + strconv.Itoa(replicaIndex)

	klog.V(1).InfoS("injectReplicaLabel", "RayCluster", namespace+"/"+clusterName, "replicaIndex", replicaLabelValue)

	labelPatch["path"] = labelPath
	labelPatch["value"] = replicaLabelValue

	*patches = append(*patches, labelPatch)
}

// inject pod affinity and anti-affinity scheduling constraints using replicaIndex label
func injectPodAffinity(pod *corev1.Pod, replicaIndex int, workerGroupName string, patches *[]patch) {
	key := "replicaIndex"
	value := workerGroupName + "-" + strconv.Itoa(replicaIndex)
	topologyKey := "cloud.google.com/gke-nodepool"
	clusterName := pod.Labels["ray.io/cluster"]
	namespace := pod.Namespace

	klog.V(1).InfoS("injectPodAffinity", "RayCluster", namespace+"/"+clusterName, "podAffinity match label", value)

	// construct affinity value to inject - schedule pods with the same replicaIndex together
	podAffinityPatch := patch{"op": "add"}

	affinitySelectorRequirement := metav1.LabelSelectorRequirement{key, metav1.LabelSelectorOpIn, []string{value}}
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

// check that the # of Ray TPU worker pods equals the # of hosts defined in the topology key
func checkWorkersMatchTopology(clusterName string, namespace string, workerGroupSpec ray.WorkerGroupSpec) (bool, error) {
	klog.V(1).InfoS("checkWorkersMatchTopology", "RayCluster", namespace+"/"+clusterName, "workerGroup", workerGroupSpec.GroupName)
	numHosts := workerGroupSpec.NumOfHosts // 1 TPU VM host -> 1 Ray worker pod
	if numHosts == 0 {
		return false, errors.New("workerGroupSpec NumOfHosts not set")
	}
	groupName := workerGroupSpec.GroupName
	containers := workerGroupSpec.Template.Spec.Containers
	if containers == nil {
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

func validateRayCluster(admissionReview *admissionv1.AdmissionReview) (*admissionv1.AdmissionResponse, error) {
	raycluster, err := extractRayCluster(admissionReview)
	if err != nil {
		klog.Fatalf("Ray Cluster extraction failed: %s", err)
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
		if containerRequestingTPUs(workerGroupSpec.Template.Spec.Containers...) {
			klog.V(1).InfoS("validateRayCluster", "RayCluster", namespace+"/"+clusterName, "Worker Group", workerGroupSpec.GroupName, "Requests TPUs", true)
			replicas := int(*workerGroupSpec.Replicas)
			numOfHosts := workerGroupSpec.NumOfHosts
			for replicaIndex := 0; replicaIndex < replicas; replicaIndex++ {
				// reset past sliceToWorkers entries for slice in ray cluster
				groupName := workerGroupSpec.GroupName
				podSlice := slice{clusterName, groupName, namespace, replicaIndex, numOfHosts}
				sliceToWorkers[podSlice] = nil
			}
		} else {
			// RayCluster worker group does not request TPUs
			klog.V(1).InfoS("validateRayCluster", "RayCluster", namespace+"/"+clusterName, "Worker Group", workerGroupSpec.GroupName, "Requests TPUs", false)
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

// gets the  next lowest-index pod slice (worker group replica) to assign a pod to in the RayCluster
// there are three possible cases here:
//  1. sliceToWorkers is empty, this is the first pod the webhook intercepts
//     - assign this pod to replica 0
//  2. The pod slice exists in sliceToWorkers, but has # created workers < NumOfHosts
//     - assign this pod to the lowest index replica with # created workers < NumOfHosts
//     - since we update isCreated when a worker is deleted, this allows us to assign re-created
//     pods to the same replica
//  3. sliceToWorkers isn't empty, but all slices have # workers == NumOfHosts
//     - this occurs when the pod we intercept is the first pod of a different slice in the cluster
//     - we keep track of how many replicas of the same worker group have been added to sliceToWorkers
//     so far, and assign this pod to the next integer replicaIndex
func getReplicaIndex(clusterName string, groupName string, namespace string) int {
	// first pod created in cluster
	if sliceToWorkers == nil {
		return 0
	}
	nextLowestId := math.MaxInt32
	numReplicas := 0 // tracks # of replicas in worker group created so far
	for slice, workerList := range sliceToWorkers {
		if slice.clusterName == clusterName && slice.groupName == groupName && slice.namespace == namespace {
			numReplicas++
			createdPods := 0
			for _, worker := range workerList {
				if worker.isCreated {
					createdPods++
				}
			}
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

// returns next lowest TPU_WORKER_ID in pod slice and updates mappings
func getNextWorkerID(podSlice slice, namespace string, replicaIndex int) int {
	tpuWorkerID := 0
	if sliceToWorkers[podSlice] == nil {
		newWorker := worker{tpuWorkerID, replicaIndex, true}
		sliceToWorkers[podSlice] = []worker{newWorker}
	} else {
		nextLowestID := math.MaxInt32
		replacePod := false
		// iterate through existing workers and check if any have been deleted
		for _, worker := range sliceToWorkers[podSlice] {
			if worker.isCreated == false && worker.workerIndex < nextLowestID {
				replacePod = true
				nextLowestID = worker.workerIndex
			}
		}
		// reassign next lowest TPU_WORKER_ID if pod has been deleted
		if replacePod == true {
			for index, worker := range sliceToWorkers[podSlice] {
				// set worker.isCreated to true now that pod is being re-created
				if worker.workerIndex == nextLowestID {
					sliceToWorkers[podSlice][index].isCreated = true
				}
			}
		} else {
			// all pods are running -> create new worker with next TPU_WORKER_ID
			nextLowestID = len(sliceToWorkers[podSlice])
			newWorker := worker{nextLowestID, replicaIndex, true}
			sliceToWorkers[podSlice] = append(sliceToWorkers[podSlice], newWorker)
		}
		tpuWorkerID = nextLowestID
	}
	klog.V(1).InfoS("getNextWorkerID", "RayCluster", namespace+"/"+podSlice.clusterName, "Worker Group", podSlice.groupName, "TPU_WORKER_ID", tpuWorkerID)
	return tpuWorkerID
}

// unmarshal pod from admission request
func extractPod(admissionReview *admissionv1.AdmissionReview) (*corev1.Pod, error) {
	if admissionReview.Request.Kind.Kind != "Pod" {
		return nil, fmt.Errorf("Expected Pod but got %s", admissionReview.Request.Kind.Kind)
	}

	pod := corev1.Pod{}
	if admissionReview.Request.Operation == "CREATE" {
		if err := json.Unmarshal(admissionReview.Request.Object.Raw, &pod); err != nil {
			return nil, err
		}
	} else if admissionReview.Request.Operation == "DELETE" {
		if err := json.Unmarshal(admissionReview.Request.OldObject.Raw, &pod); err != nil {
			return nil, err
		}
	}

	return &pod, nil
}

// add DNS hostname and TPU_WORKER_ID env var to the Pod
func mutatePod(admissionReview *admissionv1.AdmissionReview) (*admissionv1.AdmissionResponse, error) {
	pod, err := extractPod(admissionReview)
	if err != nil {
		return nil, err
	}

	var patches []patch
	// ray operator only sets GenerateName field - doesn't include random suffix until after admission request
	// use mapping of {cluster name, group name, replicaIndex} -> workers to extract next TPU_WORKER_ID
	clusterName := pod.Labels["ray.io/cluster"]
	if clusterName == "" {
		return nil, errors.New("Kuberay Pod missing RayCluster label")
	}
	containers := pod.Spec.Containers
	if containers == nil {
		return nil, errors.New("Container path not specified")
	}
	if containerRequestingTPUs(containers...) {
		namespace := pod.Namespace
		groupName := pod.Labels["ray.io/group"]
		topology := pod.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
		if topology == "" {
			klog.ErrorS(errors.New("TPU topology not specified"), "mutatePod", "RayCluster", namespace+"/"+clusterName, "gke-tpu-topology", topology)
		}
		// assign worker to the next unique ID in the pod slice and update map
		chipsPerHost := getNumTPUChipsRequested(containers...)
		numOfHosts, _ := getNumTPUHostsFromTopology(clusterName, groupName, namespace, topology, chipsPerHost) // ignore error here because topology may not be set yet
		replicaIndex := getReplicaIndex(clusterName, groupName, namespace)
		podSlice := slice{clusterName, groupName, namespace, replicaIndex, numOfHosts}
		tpuWorkerID := getNextWorkerID(podSlice, namespace, replicaIndex) // defaults to 0 for single-host

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
					klog.V(1).InfoS("mutatePod", "RayCluster", namespace+"/"+clusterName, "subdomain", clusterName+"-"+headlessServiceSuffix)
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
	}

	patchBytes, err := json.Marshal(patches)
	if err != nil {
		return nil, err
	}

	admissionResponse := &admissionv1.AdmissionResponse{
		UID:     admissionReview.Request.UID,
		Allowed: true,
		Patch:   patchBytes,
		PatchType: func() *admissionv1.PatchType {
			pt := admissionv1.PatchTypeJSONPatch
			return &pt
		}(),
	}
	return admissionResponse, nil
}

// update sliceToWorkers map on pod deletion
func deletePod(admissionReview *admissionv1.AdmissionReview) (*admissionv1.AdmissionResponse, error) {
	// Create AdmissionResponse - we never deny the deletion request
	admissionResponse := &admissionv1.AdmissionResponse{
		UID:     admissionReview.Request.UID,
		Allowed: true,
		Result: &metav1.Status{
			Status:  "Success",
			Message: "",
		},
	}

	pod, err := extractPod(admissionReview)
	if err != nil {
		klog.Errorf("Pod extraction failed: %s", err)
	}

	clusterName := pod.Labels["ray.io/cluster"]
	if clusterName == "" {
		return admissionResponse, errors.New("Kuberay Pod missing RayCluster label")
	}
	groupName := pod.Labels["ray.io/group"]
	if groupName == "" {
		return admissionResponse, errors.New("Kuberay Pod missing Ray group label")
	}
	namespace := pod.Namespace
	replicaIndexLabel := pod.Labels["replicaIndex"]

	if replicaIndexLabel != "" {
		replicaIndexLabelValues := strings.Split(replicaIndexLabel, "-")
		replicaIndex, _ := strconv.Atoi(replicaIndexLabelValues[len(replicaIndexLabelValues)-1]) // ignore error here since must be set

		containers := pod.Spec.Containers
		if containers == nil {
			return admissionResponse, errors.New("Pod spec missing containers")
		}
		tpuWorkerID := -1
		for _, container := range pod.Spec.Containers {
			if containerRequestingTPUs(container) {
				tpuWorkerID, err = strconv.Atoi(getEnvironmentVariable("TPU_WORKER_ID", container))
				if err != nil {
					return admissionResponse, errors.New("Unable to extract TPU_WORKER_ID")
				}
				break
			}
		}
		if tpuWorkerID == -1 {
			return admissionResponse, errors.New("Kuberay Pod missing TPU_WORKER_ID")
		}
		// update sliceToWorkers map
		for slice, _ := range sliceToWorkers {
			if slice.clusterName == clusterName && slice.groupName == groupName && slice.namespace == namespace && slice.replicaIndex == replicaIndex {
				// set the pod state to indicate it is not running
				for index, worker := range sliceToWorkers[slice] {
					if worker.workerIndex == tpuWorkerID {
						sliceToWorkers[slice][index].isCreated = false
						klog.V(1).InfoS("deletePod", "RayCluster", namespace+"/"+clusterName, "TPU_WORKER_ID", tpuWorkerID, "Replica Index", replicaIndex)
						break
					}
				}
				break
			}
		}
	}

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
	sliceToWorkers = make(map[slice][]worker)

	flag.StringVar(&BindAddr, "bind-address", ":443", "Address to bind HTTPS service to")
	flag.StringVar(&CACert, "ca-cert", "", "base64-encoded root certificate for TLS")
	flag.StringVar(&ServerCert, "server-cert", "", "base64-encoded server certificate for TLS")
	flag.StringVar(&ServerKey, "server-key", "", "base64-encoded server key for TLS")

	// set klog verbosity level
	klog.InitFlags(nil)
}

func main() {
	flag.Parse()

	mux := http.NewServeMux()

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, "kuberay-tpu-webhook")
	})
	mux.HandleFunc("/mutate", func(w http.ResponseWriter, r *http.Request) {
		admissionReview := &admissionv1.AdmissionReview{}
		if err := json.NewDecoder(r.Body).Decode(admissionReview); err != nil {
			http.Error(w, "Error decoding request body", http.StatusBadRequest)
			return
		}

		if admissionReview.Request.Kind.Kind == "Pod" {
			klog.V(1).Info("Received review for Pod creation")
			response, err := mutatePod(admissionReview)
			if err != nil {
				klog.Errorf("Failed to mutate pod: %s", err)
				return
			}
			admissionReview.Response = response
			responseBytes, err := json.Marshal(admissionReview)
			if err != nil {
				klog.Errorf("Failed to encode response: %s", err)
				return
			}
			fmt.Fprint(w, string(responseBytes))
		}
	})

	mux.HandleFunc("/validate", func(w http.ResponseWriter, r *http.Request) {
		admissionReview := &admissionv1.AdmissionReview{}
		if err := json.NewDecoder(r.Body).Decode(admissionReview); err != nil {
			http.Error(w, "Error decoding request body", http.StatusBadRequest)
			return
		}

		if admissionReview.Request.Kind.Kind == "Pod" {
			klog.V(0).Info("Received review for Pod deletion")
			response, err := deletePod(admissionReview)
			if err != nil {
				klog.Errorf("Failed to validate pod deletion: %s", err)
				return
			}
			admissionReview.Response = response
			responseBytes, err := json.Marshal(admissionReview)
			if err != nil {
				klog.Errorf("Failed to encode response: %s", err)
				return
			}
			fmt.Fprint(w, string(responseBytes))
		}

		if admissionReview.Request.Kind.Kind == "RayCluster" {
			klog.V(0).Info("Received review for RayCluster")
			response, err := validateRayCluster(admissionReview)
			if err != nil {
				klog.Errorf("Failed to validate ray cluster: %s", err)
				return
			}
			admissionReview.Response = response
			responseBytes, err := json.Marshal(admissionReview)
			if err != nil {
				klog.Errorf("Failed to encode response: %s", err)
				return
			}
			fmt.Fprint(w, string(responseBytes))
		}
	})

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
