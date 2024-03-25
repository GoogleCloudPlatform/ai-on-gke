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
	headlessServiceName   string

	// map of pod slices to workers in the slice
	sliceToWorkers map[slice][]worker

	// map of pod slices to TPU_WORKER_HOSTNAMES in that pod slice
	sliceToHostnames map[slice]string

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

func getNumTPUHostsFromTopology(topology string, acceleratorType string) (int32, error) {
	if topology == "" {
		return 0, errors.New("TPU topology not specified")
	}
	topologyVals := strings.Split(topology, "x")
	chips := 1
	for i := 0; i < len(topologyVals); i++ {
		dim, err := strconv.Atoi(topologyVals[i])
		if err != nil {
			klog.Errorf("Invalid topology: %s", err)
			return 0, err
		}
		chips *= dim
	}
	// calculate the # of VMs using # of chips per host
	acceleratorTypeValues := strings.Split(acceleratorType, "-")
	chipsPerHost := 4 // default to 4 chips per VM
	if acceleratorTypeValues[0] == "v5litepod" {
		// v5e TPU VMs can have 1, 4 or 8 chips
		chipsPerHost, err := strconv.Atoi(acceleratorTypeValues[1])
		if err != nil {
			klog.Errorf("Unexpected acceleratorType: %s", acceleratorType)
		}
		chipsPerHost = min(chipsPerHost, 8) // max of 8 chips per host
	}
	return int32(max(chips/chipsPerHost, 1)), nil
}

// check if request is for TPU multi-host
func isTPUMultiHost(topology string, acceleratorType string) (bool, error) {
	vms, err := getNumTPUHostsFromTopology(topology, acceleratorType)
	if err != nil {
		return false, err
	}

	return (vms > 1), nil
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

func genDNSHostnames(workerGroupSpec ray.WorkerGroupSpec, replicaIndex int) (string, error) {
	numHosts := workerGroupSpec.NumOfHosts
	if numHosts == 0 {
		return "", errors.New("workerGroupSpec NumOfHosts not set")
	}
	workerGroupName := workerGroupSpec.GroupName
	hostNames := make([]string, numHosts)
	// Host names will be of the form {WORKER_GROUP_NAME}-{REPLICA_INDEX}-{HOST_INDEX}.headless-worker-svc
	for j := 0; j < int(numHosts); j++ {
		hostNames[j] = fmt.Sprintf("%s-%d-%d.%s", workerGroupName, replicaIndex, j, headlessServiceName)
	}
	return strings.Join(hostNames, ","), nil
}

// inject subdomain and TPU_WORKER_HOSTNAMES into pods for TPU multi-host initialization
func injectHostnames(hostNames string, envPath string, container corev1.Container, patches *[]patch) {
	subdomainPatch, hostNamesPatch := patch{"op": "add"}, patch{"op": "add"}
	subdomainPath := "/spec/subdomain"
	tpuWorkerHostNames := corev1.EnvVar{
		Name:  "TPU_WORKER_HOSTNAMES",
		Value: hostNames,
	}
	subdomainPatch["path"] = subdomainPath
	subdomainPatch["value"] = headlessServiceName
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

func injectMultiHostReplicaLabel(replicaIndex int, workerGroupName string, patches *[]patch) {
	labelPatch := patch{"op": "replace"}
	labelPath := "/metadata/labels/multiHostReplica"
	multiHostReplicaValue := workerGroupName + "-" + strconv.Itoa(replicaIndex)

	labelPatch["path"] = labelPath
	labelPatch["value"] = multiHostReplicaValue

	*patches = append(*patches, labelPatch)
}

// inject pod affinity and anti-affinity scheduling constraints using multiHostReplica label
func injectPodAffinity(pod *corev1.Pod, replicaIndex int, workerGroupName string, patches *[]patch) {
	key := "multiHostReplica"
	value := workerGroupName + "-" + strconv.Itoa(replicaIndex)
	topologyKey := "cloud.google.com/gke-nodepool"

	// construct affinity value to inject - schedule pods with the same multiHostReplica together
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
func checkWorkersMatchTopology(workerGroupSpec ray.WorkerGroupSpec) (bool, error) {
	numHosts := workerGroupSpec.NumOfHosts // 1 TPU VM host -> 1 Ray worker pod
	if numHosts == 0 {
		return false, errors.New("workerGroupSpec NumOfHosts not set")
	}
	containers := workerGroupSpec.Template.Spec.Containers
	if containers == nil {
		return false, errors.New("Container path not specified")
	}
	if containerRequestingTPUs(containers...) {
		topology := workerGroupSpec.Template.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
		acceleratorType := workerGroupSpec.Template.Spec.NodeSelector["cloud.google.com/gke-tpu-accelerator"]
		if topology == "" {
			klog.Error("TPU topology not specified")
		}
		if acceleratorType == "" {
			klog.Error("TPU accelerator type not specified")
		}
		expectedHosts, err := getNumTPUHostsFromTopology(topology, acceleratorType)
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
	headlessServiceName = fmt.Sprintf("%s-%s", clusterName, headlessServiceSuffix)
	workerGroupSpecs := raycluster.Spec.WorkerGroupSpecs
	if workerGroupSpecs == nil {
		return nil, errors.New("WorkerGroupSpecs not specified")
	}
	for i := 0; i < len(workerGroupSpecs); i++ {
		workerGroupSpec := workerGroupSpecs[i]
		// create mapping for pod slices -> TPU_WORKER_HOSTNAMES in cluster
		replicas := int(*workerGroupSpec.Replicas)
		numOfHosts := workerGroupSpec.NumOfHosts
		if numOfHosts > 1 {
			for replicaIndex := 0; replicaIndex < replicas; replicaIndex++ {
				// reset past sliceToWorkers and sliceToHostnames entries for slice in ray cluster
				groupName := workerGroupSpec.GroupName
				podSlice := slice{clusterName, groupName, replicaIndex, numOfHosts}
				sliceToWorkers[podSlice] = nil
				sliceToHostnames[podSlice] = ""
				// generate TPU_WORKER_HOSTNAMES
				joinedHostNames, err := genDNSHostnames(workerGroupSpec, replicaIndex)
				if err != nil {
					klog.Error("Failed to generate DNS Hostnames")
				}
				sliceToHostnames[podSlice] = joinedHostNames
			}
		}
		// validate NumOfHosts for worker group matches topology nodeSelector
		workersMatchTopology, err := checkWorkersMatchTopology(workerGroupSpec)
		if err != nil {
			return nil, err
		}

		if !workersMatchTopology {
			admit = false
			status = "Failure"
			message = "Number of workers in worker group not equal to specified topology"
		}
		break
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

// get next lowest-index pod slice to assign a pod to in the RayCluster
// this will be the first pod slice with # created pods < NumOfHosts
func getReplicaIndex(clusterName string) int {
	if sliceToWorkers == nil {
		return 0
	}
	next_lowest_id := math.MaxInt32
	for slice, workerList := range sliceToWorkers {
		if slice.clusterName == clusterName {
			createdPods := 0
			for _, worker := range workerList {
				if worker.isCreated {
					createdPods++
				}
			}
			if createdPods < int(slice.numOfHosts) {
				if slice.replicaIndex < next_lowest_id {
					next_lowest_id = slice.replicaIndex
				}
			}
		}
	}
	return next_lowest_id
}

// returns next lowest TPU_WORKER_ID in pod slice and updates mappings
func getNextWorkerID(podSlice slice, replicaIndex int) int {
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
			for _, worker := range sliceToWorkers[podSlice] {
				// set worker.isCreated to true now that pod is being re-created
				if worker.workerIndex == nextLowestID {
					worker.isCreated = true
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
	groupName := pod.Labels["ray.io/group"]
	topology := pod.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
	acceleratorType := pod.Spec.NodeSelector["cloud.google.com/gke-tpu-accelerator"]
	if topology == "" {
		klog.Error("TPU topology not specified")
	}
	if acceleratorType == "" {
		klog.Error("TPU accelerator type not specified")
	}
	containers := pod.Spec.Containers
	if containers == nil {
		return nil, errors.New("Container path not specified")
	}
	if containerRequestingTPUs(containers...) {
		// assign worker to the next unique ID in the pod slice and update map
		numOfHosts, _ := getNumTPUHostsFromTopology(topology, acceleratorType) // ignore error here because topology may not be set yet
		replicaIndex := getReplicaIndex(clusterName)
		podSlice := slice{clusterName, groupName, replicaIndex, numOfHosts}
		tpuWorkerID := 0 // defaults to 0 for single-host

		isMultiHost, _ := isTPUMultiHost(topology, acceleratorType) // ignore error here because topology may not be set yet
		if isMultiHost {
			// get next unique TPU_WORKER_ID for multi-host slice
			tpuWorkerID = getNextWorkerID(podSlice, replicaIndex)

			// inject hostname into pod spec for DNS records
			hostname := fmt.Sprintf(groupName+"-%d-%d", replicaIndex, tpuWorkerID)
			hostnamePatch := patch{"op": "add"}
			hostnamePatch["path"] = "/spec/hostname"
			hostnamePatch["value"] = hostname
			patches = append(patches, hostnamePatch)

			// inject multi-host replica label
			injectMultiHostReplicaLabel(replicaIndex, groupName, &patches)

			// inject pod affinity/anti-affinity for scheduling
			injectPodAffinity(pod, replicaIndex, groupName, &patches)
		}

		// inject all environment variables into the container requesting TPUs
		for i := 0; i < len(containers); i++ {
			container := containers[i]
			if containerRequestingTPUs(container) {
				path := fmt.Sprintf("/spec/containers/%d/env", i)
				if isMultiHost {
					// inject TPU_WORKER_HOSTNAMES set during RayCluster interception
					injectHostnames(sliceToHostnames[podSlice], path, container, &patches)
				}
				// inject TPU_WORKER_ID
				if getEnvironmentVariable("TPU_WORKER_ID", container) == "" {
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
					tpuName := corev1.EnvVar{
						Name:  "TPU_NAME",
						Value: fmt.Sprintf("%s-%d", groupName, replicaIndex),
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
	pod, err := extractPod(admissionReview)
	if err != nil {
		klog.Fatalf("Pod extraction failed: %s", err)
	}

	multiHostReplicaLabel := pod.Labels["multiHostReplica"]

	if multiHostReplicaLabel != "" {
		multiHostReplicaLabelValues := strings.Split(multiHostReplicaLabel, "-")
		groupName := multiHostReplicaLabelValues[0]
		replicaIndex, _ := strconv.Atoi(multiHostReplicaLabelValues[1]) // ignore error here since must be set

		containers := pod.Spec.Containers
		if containers == nil {
			return nil, errors.New("Pod spec missing containers")
		}
		tpuWorkerID := -1
		for _, container := range pod.Spec.Containers {
			if containerRequestingTPUs(container) {
				tpuWorkerID, err = strconv.Atoi(getEnvironmentVariable("TPU_WORKER_ID", container))
				if err != nil {
					return nil, errors.New("Unable to extract TPU_WORKER_ID")
				}
			}
		}
		// pod belongs to a multi-host replica -> update the map
		for slice, _ := range sliceToWorkers {
			if slice.groupName == groupName && slice.replicaIndex == replicaIndex {
				// set the pod state to indicate it is not running
				for _, worker := range sliceToWorkers[slice] {
					if worker.workerIndex == tpuWorkerID {
						worker.isCreated = false
						break
					}
				}
				break
			}
		}
	}

	// Create AdmissionResponse - we never deny the deletion request
	admissionResponse := &admissionv1.AdmissionResponse{
		UID:     admissionReview.Request.UID,
		Allowed: true,
		Result: &metav1.Status{
			Status:  "Success",
			Message: "",
		},
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
	sliceToHostnames = make(map[slice]string)

	flag.StringVar(&BindAddr, "bind-address", ":443", "Address to bind HTTPS service to")
	flag.StringVar(&CACert, "ca-cert", "", "base64-encoded root certificate for TLS")
	flag.StringVar(&ServerCert, "server-cert", "", "base64-encoded server certificate for TLS")
	flag.StringVar(&ServerKey, "server-key", "", "base64-encoded server key for TLS")
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
			klog.Info("Received review for Pod")
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
			klog.Info("Received review for Pod deletion")
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
			klog.Info("Received review for RayCluster")
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
			klog.Info("Server closed")
			return
		}
		klog.Error("Failed to start server")
	}
}
