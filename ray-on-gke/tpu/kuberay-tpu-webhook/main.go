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
	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	listersv1 "k8s.io/client-go/listers/core/v1"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
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

// JSON patch describing mutate operation(s) for incoming object
type patch map[string]any

var (
	certPath        = "/etc/kuberay-tpu-webhook/tls/tls.crt"
	keyPath         = "/etc/kuberay-tpu-webhook/tls/tls.key"
	tpuResourceName = corev1.ResourceName("google.com/tpu")

	// headless svc will be of the form: {kuberay-cluster-name}-headless-worker-svc
	headlessServiceSuffix = "headless-worker-svc"

	// k8s Pod informer to query current cluster Pod list
	// TODO: refactor webhook to remove global vars
	podLister listersv1.PodLister

	// map of pod slices to workers in the slice
	sliceToWorkerIDs map[slice][]int

	// mutex lock for webhook go routines accessing Informer cache
	cacheMutex sync.Mutex

	// mutex lock for webhook go routines accessing sliceToWorkerIDs mapping
	readMutex sync.Mutex

	// Flag arguments.
	BindAddr       string
	CACert         string
	KubeConfigPath string
	ServerCert     string
	ServerKey      string
)

// helper function used for logging and testing
func printSliceToWorkerIds() {
	for slice, workerList := range sliceToWorkerIDs {
		klog.V(1).InfoS("printSliceToWorkerIds", "RayCluster", slice.namespace+"/"+slice.clusterName, "Worker Group", slice.groupName)
		for _, workerID := range workerList {
			klog.V(1).InfoS("printSliceToWorkerIds", "RayCluster", slice.namespace+"/"+slice.clusterName, "Worker ID", workerID)
		}
	}
}

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
		klog.ErrorS(err, "genDNSHostnames", "RayCluster", namespace+"/"+clusterName, "NumOfHosts", numOfHosts)
		return "", err
	}
	hostNames := make([]string, numOfHosts)
	// Host names will be of the form {WORKER_GROUP_NAME}-{REPLICA_INDEX}-{HOST_INDEX}.headless-worker-svc
	for j := 0; j < int(numOfHosts); j++ {
		hostNames[j] = fmt.Sprintf("%s-%d-%d.%s-%s", groupName, replicaIndex, j, clusterName, headlessServiceSuffix)
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
//  1. sliceToWorkerIDs is empty, this is the first pod the webhook intercepts
//     - assign this pod to replica 0
//  2. The pod slice exists in sliceToWorkerIDs, but has # created workers < NumOfHosts
//     - assign this pod to the lowest index replica with # created workers < NumOfHosts
//     pods to the same replica
//  3. sliceToWorkerIDs isn't empty, but all slices have # workers == NumOfHosts
//     - this occurs when the pod we intercept is the first pod of a different slice in the cluster
//     - we keep track of how many replicas of the same worker group have been added to sliceToWorkerIDs
//     so far, and assign this pod to the next integer replicaIndex
func getReplicaIndex(clusterName string, groupName string, namespace string) int {
	// webhook go routine acquires read lock
	readMutex.Lock()
	defer readMutex.Unlock()

	// first pod created in cluster
	if sliceToWorkerIDs == nil {
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

// returns next lowest TPU_WORKER_ID in pod slice and updates mappings
func getNextWorkerID(podSlice slice, namespace string, replicaIndex int) int {
	// webhook go routine acquires read lock
	readMutex.Lock()
	defer readMutex.Unlock()

	tpuWorkerID := 0 // defaults to 0 (first Pod in slice)
	if sliceToWorkerIDs[podSlice] != nil {
		sort.Ints(sliceToWorkerIDs[podSlice])
		// iterate through existing workers and get the next lowest, unused ID
		for _, workerID := range sliceToWorkerIDs[podSlice] {
			if workerID == tpuWorkerID {
				tpuWorkerID++
			}
		}
	}
	klog.V(1).InfoS("getNextWorkerID", "RayCluster", namespace+"/"+podSlice.clusterName, "Worker Group", podSlice.groupName, "TPU_WORKER_ID", tpuWorkerID)
	return tpuWorkerID
}

// builds mapping representing the current RayCluster state of TPU pods using PodInformer
func updateSliceToWorkerIDs(clusterName string, groupName string, namespace string, numOfHosts int32) error {
	// webhook go routine acquires cache lock
	cacheMutex.Lock()
	defer cacheMutex.Unlock()

	sliceToWorkerIDs = make(map[slice][]int)

	// retrieve list of Pods in the same Ray worker group as the intercepted Pod
	if podLister == nil {
		return errors.New("k8s Pod Informer Lister not initialized")
	}
	podsInGroup, err := podLister.Pods(namespace).List(labels.SelectorFromSet(labels.Set{"ray.io/group": groupName}))
	if err != nil {
		return err
	}

	if podsInGroup == nil {
		return nil
	}
	klog.V(1).InfoS("updateSliceToWorkerIDs", "RayCluster", namespace+"/"+clusterName, "# Pods in Group", len(podsInGroup))
	for _, existingPod := range podsInGroup {
		if existingPod.Status.Phase != "Pending" && existingPod.Status.Phase != "Running" {
			continue
		}
		existingClusterName := existingPod.Labels["ray.io/cluster"]
		existingGroupName := existingPod.Labels["ray.io/group"]
		existingNamespace := existingPod.Namespace
		// we only care about workers in the same RayCluster and worker group when assigning IDs
		if clusterName == existingClusterName && groupName == existingGroupName && namespace == existingNamespace {
			if containerRequestingTPUs(existingPod.Spec.Containers...) {
				replicaIndexLabel := existingPod.Labels["replicaIndex"]
				if replicaIndexLabel != "" {
					replicaIndexLabelValues := strings.Split(replicaIndexLabel, "-")
					existingReplicaIndex, _ := strconv.Atoi(replicaIndexLabelValues[len(replicaIndexLabelValues)-1])
					existingWorkerID := -1
					for _, container := range existingPod.Spec.Containers {
						if containerRequestingTPUs(container) {
							tpuWorkerIDEnvVar := getEnvironmentVariable("TPU_WORKER_ID", container)
							tempVar, err := strconv.Atoi(tpuWorkerIDEnvVar)
							if err != nil {
								klog.ErrorS(err, "updateSliceToWorkerIDs", "RayCluster", namespace+"/"+clusterName, "TPU_WORKER_ID", tpuWorkerIDEnvVar)
								continue
							}
							existingWorkerID = tempVar
							break
						}
					}
					if existingPod.Status.Phase == "Running" && existingWorkerID == -1 {
						return errors.New("existing TPU worker missing TPU_WORKER_ID")
					}
					if existingWorkerID != -1 {
						// Pod has been intercepted by the webhook
						podSlice := slice{existingClusterName, existingGroupName, namespace, existingReplicaIndex, numOfHosts}
						if sliceToWorkerIDs[podSlice] == nil {
							sliceToWorkerIDs[podSlice] = []int{existingWorkerID}
						} else {
							sliceToWorkerIDs[podSlice] = append(sliceToWorkerIDs[podSlice], existingWorkerID)
						}
						klog.V(1).InfoS("updateSliceToWorkerIDs", "RayCluster", namespace+"/"+clusterName, "ReplicaIndex", existingReplicaIndex, "TPU_WORKER_ID", existingWorkerID)
					}
				}
			}
		}
	}
	return nil
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
	containers := pod.Spec.Containers
	if containers == nil {
		return nil, errors.New("Container path not specified")
	}
	if containerRequestingTPUs(containers...) {
		// ray operator only sets GenerateName field - doesn't include random suffix until after admission request
		// use mapping of {cluster name, group name, replicaIndex} -> workers to extract next TPU_WORKER_ID
		clusterName := pod.Labels["ray.io/cluster"]
		if clusterName == "" {
			return nil, errors.New("Kuberay Pod missing RayCluster label")
		}
		groupName := pod.Labels["ray.io/group"]
		if groupName == "" {
			return nil, errors.New("Kuberay Pod missing Group label")
		}
		namespace := pod.Namespace
		topology := pod.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
		if topology == "" {
			klog.ErrorS(errors.New("TPU topology not specified"), "mutatePod", "RayCluster", namespace+"/"+clusterName, "gke-tpu-topology", topology)
		}
		// assign worker to the next unique ID in the pod slice and update map
		chipsPerHost := getNumTPUChipsRequested(containers...)
		numOfHosts, _ := getNumTPUHostsFromTopology(clusterName, groupName, namespace, topology, chipsPerHost) // ignore error here because topology may not be set yet

		// query k8s client to populate sliceToWorkerIDs to then calculate the next TPU_WORKER_ID and replicaIndex
		err := updateSliceToWorkerIDs(clusterName, groupName, namespace, numOfHosts)
		if err != nil {
			return nil, err
		}
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
	factory := informers.NewFilteredSharedInformerFactory(client, 5*time.Minute, metav1.NamespaceAll, tweakListOptionsFunc)
	podLister = factory.Core().V1().Pods().Lister()

	// start the PodInformer and wait for cache sync
	stopCh := make(chan struct{})
	factory.Start(stopCh)
	factory.WaitForCacheSync(stopCh)

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
