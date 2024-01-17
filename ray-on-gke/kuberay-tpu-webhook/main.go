package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"strconv"

	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	ray "github.com/ray-project/kuberay/ray-operator/apis/ray/v1"
	"k8s.io/klog/v2"
)

// our representation of a pod slice
// not necessarily true that worker group scheduled on 1 slice
type slice struct {
	rayClusterName	string
	groupName	string
}

// JSON patch describing mutate operation(s) for incoming object
type patch map[string]any

var (
	certPath = "/etc/kuberay-tpu-webhook/tls/tls.crt"
	keyPath = "/etc/kuberay-tpu-webhook/tls/tls.key"
	tpuResourceName = corev1.ResourceName("google.com/tpu")

	// headless svc will be of the form: {kuberay-cluster-name}-tpu-worker-svc
	headlessServiceSuffix = "tpu-worker-svc"
	headlessServiceName string

	// map of ray cluster names to # of workers created in the slice
	sliceToWorkers map[slice]int
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

func getNumTPUHosts(topology string) (int, error) {
	if topology == "" {
		return 0, errors.New("TPU topology not specified")
	}
	topologyVals :=  strings.Split(topology, "x")
	chips := 1
	for i := 0; i < len(topologyVals); i++ {
		dim, err := strconv.Atoi(topologyVals[i])
		if err != nil {
			klog.Errorf("Invalid topology: %s", err)
			return 0, err
		}
		chips *= dim
	}
	// number VMs = number chips / 4
	return max(chips / 4, 1), nil
}

// check if request is for TPU multi-host
func isTPUMultiHost(topology string) (bool, error) {
	vms, err := getNumTPUHosts(topology)
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

func genDNSHostnames(workerGroupSpec ray.WorkerGroupSpec) (string, error) {
	replicas := workerGroupSpec.Replicas
	if replicas == nil {
		return "", errors.New("workerGroupSpec replicas not set")
	}
	numWorkers := int(*replicas)
	workerGroupName := workerGroupSpec.GroupName
	hostNames := make([]string, numWorkers)
	for j := 0; j < numWorkers; j++ {
		hostNames[j] = fmt.Sprintf("%s-%d.%s", workerGroupName, j, headlessServiceName)
	}
	return strings.Join(hostNames, ","), nil
}

func injectHostnames(hostNames string, workerGroupSpec ray.WorkerGroupSpec, workerGroupIndex int, patches *[]patch) {
	containers := workerGroupSpec.Template.Spec.Containers
	if containers == nil {
		klog.Fatalf("Container path not specified")
	}
	// inject subdomain and TPU_WORKER_HOSTNAMES into pods for TPU multi-host initialization
	for j := 0; j < len(containers); j++ {
		container := containers[j]
		if containerRequestingTPUs(container) {
			subdomainPatch, hostNamesPatch := patch{"op": "add",}, patch{"op": "add",}
			subdomainPath := fmt.Sprintf("/spec/workerGroupSpecs/%d/template/spec/subdomain", workerGroupIndex)
			envPath := fmt.Sprintf("/spec/workerGroupSpecs/%d/template/spec/containers/%d/env", workerGroupIndex, j)
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
	}
}

func checkWorkersMatchTopology(workerGroupSpec ray.WorkerGroupSpec) (bool, error) {
	replicas := workerGroupSpec.Replicas
	if replicas == nil {
		return false, errors.New("workerGroupSpec replicas not set")
	}
	numWorkers := int(*replicas)
	containers := workerGroupSpec.Template.Spec.Containers
	if containers == nil {
		return false, errors.New("Container path not specified")
	}
	if containerRequestingTPUs(containers...) {
		topology := workerGroupSpec.Template.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
		if topology == "" {
			klog.Error("TPU topology not specified")
		}
		hosts, err := getNumTPUHosts(topology)
		if err != nil {
			return false, err
		}

		if hosts != numWorkers {
			return false, nil
		}
	}
	return true, nil
}

func isScheduledWithAffinity(workerGroupSpec ray.WorkerGroupSpec) (bool, error) {
	containers := workerGroupSpec.Template.Spec.Containers
	if containers == nil {
		return false, errors.New("Container path not specified")
	}
	if containerRequestingTPUs(containers...) {
		topology := workerGroupSpec.Template.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
		isMultiHost, err := isTPUMultiHost(topology)
		if err != nil {
			return false, err
		}
		if isMultiHost {
			placementGroup := workerGroupSpec.Template.Spec.NodeSelector["cloud.google.com/gke-placement-group"]
			if placementGroup == "" {
				return false, nil	
			}
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
	workerGroupSpecs := raycluster.Spec.WorkerGroupSpecs
	if workerGroupSpecs == nil {
		return nil, errors.New("WorkerGroupSpecs not specified")
	}
	for i := 0; i < len(workerGroupSpecs); i++ {
		workerGroupSpec := workerGroupSpecs[i]
		workersMatchTopology, err := checkWorkersMatchTopology(workerGroupSpec)
		if err != nil {
			return nil, err
		}
		hasCorrectAffinity, err := isScheduledWithAffinity(workerGroupSpec)
		if err != nil {
			return nil, err
		}

		if !(workersMatchTopology && hasCorrectAffinity) {
			admit = false
			status = "Failure"
			if !workersMatchTopology && !hasCorrectAffinity {
				message = "Missing gke-placement-group nodeSelector and workers not equal to specified topology"
			} else if !workersMatchTopology {
				message = "Number of workers in worker group not equal to specified topology"
			} else if !hasCorrectAffinity {
				message = "TPU worker group requested without gke-placement-group nodeSelector"
			}
			break
		}
	}
	
	// Create AdmissionResponse
	admissionResponse := &admissionv1.AdmissionResponse{
		UID: 	 admissionReview.Request.UID,
		Allowed: admit,
		Result:	 &metav1.Status{
			Status:	 status,
			Message: message,
		},
	}
	return admissionResponse, nil
}

// add TPU_WORKER_HOSTNAMES to containers in a ray cluster
func mutateRayCluster(admissionReview *admissionv1.AdmissionReview) (*admissionv1.AdmissionResponse, error) {
	raycluster, err := extractRayCluster(admissionReview)
	if err != nil {
		return nil, err
	}

	clusterName := raycluster.Name
	headlessServiceName = fmt.Sprintf("%s-%s", clusterName, headlessServiceSuffix)
	var patches []patch
	workerGroupSpecs := raycluster.Spec.WorkerGroupSpecs
	if workerGroupSpecs == nil {
		return nil, errors.New("WorkerGroupSpecs not specified")
	}
	for i := 0; i < len(workerGroupSpecs); i++ {
		workerGroupSpec := workerGroupSpecs[i]
		// reset past sliceToWorkers entries for ray cluster
		groupName := workerGroupSpec.GroupName
		podSlice := slice{clusterName, groupName}
		sliceToWorkers[podSlice] = 0

		containers := workerGroupSpec.Template.Spec.Containers
		if containers == nil {
			return nil, errors.New("Container path not specified")
		}
		if containerRequestingTPUs(containers...) {
			topology := workerGroupSpec.Template.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
			isMultiHost, err := isTPUMultiHost(topology)
			if err != nil {
				return nil, err
			}
			if isMultiHost {
				joinedHostNames, err := genDNSHostnames(workerGroupSpec)
				if err != nil {
					return nil, err
				}
				injectHostnames(joinedHostNames, workerGroupSpec, i, &patches)
			}
		}
	}

	patchBytes, err := json.Marshal(patches)
	if err != nil {
		return nil, err
	}

 	// Create AdmissionResponse
	admissionResponse := &admissionv1.AdmissionResponse{
		UID: 	 admissionReview.Request.UID,
		Allowed: true,
		Patch:   patchBytes,
		PatchType: func() *admissionv1.PatchType {
			pt := admissionv1.PatchTypeJSONPatch
			return &pt
		}(),
	}
	return admissionResponse, nil
}

func hasWorkerID(container corev1.Container) bool {
	if container.Env != nil && len(container.Env) > 0 {
		for _, envVar := range container.Env  {
			if envVar.Name == "TPU_WORKER_ID" {
				return true
			}
		}
	}
	return false
}

func hasWorkerName(container corev1.Container) bool {
	if container.Env != nil && len(container.Env) > 0 {
		for _, envVar := range container.Env {
			if envVar.Name == "TPU_NAME" {
				return true
			}
		}
	}
	return false
}

// unmarshal pod from admission request
func extractPod(admissionReview *admissionv1.AdmissionReview) (*corev1.Pod, error) {
	if admissionReview.Request.Kind.Kind != "Pod" {
		return nil, fmt.Errorf("Expected Pod but got %s", admissionReview.Request.Kind.Kind)
	}

	pod := corev1.Pod{}
	if err := json.Unmarshal(admissionReview.Request.Object.Raw, &pod); err != nil {
		return nil, err
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
	// use mapping of {cluster name, group name} -> # workers created to set TPU_WORKER_IDs
	clusterName := pod.Labels["ray.io/cluster"]
	groupName := pod.Labels["ray.io/group"]
	podSlice := slice{clusterName, groupName}
	topology := pod.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
	if topology == "" {
		klog.Error("TPU topology not specified")
	}
	containers := pod.Spec.Containers
	if containers == nil {
		return nil, errors.New("Container path not specified")
	}
	if containerRequestingTPUs(containers...) {
		// assign to the next unique ID in the pod slice
		tpu_worker_id := sliceToWorkers[podSlice]

		// if multihost -> inject hostname into pod spec for DNS records
		isMultiHost, _ := isTPUMultiHost(topology) // ignore error here because topology may not be set yet
		if isMultiHost {
			hostname := fmt.Sprintf(groupName + "-%d", tpu_worker_id)
			hostnamePatch := patch{"op": "add",}
			hostnamePatch["path"] = "/spec/hostname"
			hostnamePatch["value"] = hostname
			patches = append(patches, hostnamePatch)
		}

		// inject the TPU_WORKER_ID environment variable into the container requesting TPUs
		increment_worker_id := false
		for i := 0; i < len(containers); i++ {
			container := containers[i]
			if containerRequestingTPUs(container) {
				path := fmt.Sprintf("/spec/containers/%d/env", i)
				if !hasWorkerID(container) {
					increment_worker_id = true
					tpuWorkerID := corev1.EnvVar{
						Name:  "TPU_WORKER_ID",
						Value: fmt.Sprint(tpu_worker_id),
					}
					idPatch := patch{"op": "add",}
					// create new EnvVar array if container.Env is empty, and append new EnvVars if not
					if len(container.Env) == 0 {
						idPatch["path"] = path
						idPatch["value"] = []corev1.EnvVar{tpuWorkerID}
					} else {
						idPatch["path"] = fmt.Sprintf("%s/-", path)
						idPatch["value"] = tpuWorkerID
					}
					patches = append(patches, idPatch)
				}
				if !hasWorkerName(container) {
					tpuName := corev1.EnvVar{
						Name:  "TPU_NAME",
						Value: fmt.Sprint(groupName),
					}
					namePatch := patch{"op": "add",}
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
		if increment_worker_id {
			sliceToWorkers[podSlice] += 1
		}
	}

	patchBytes, err := json.Marshal(patches)
	if err != nil {
		return nil, err
	}

	admissionResponse := &admissionv1.AdmissionResponse{
		UID: 	 admissionReview.Request.UID,
		Allowed: true,
		Patch:   patchBytes,
		PatchType: func() *admissionv1.PatchType {
			pt := admissionv1.PatchTypeJSONPatch
			return &pt
		}(),
	}
	return admissionResponse, nil
}

func init() {
	sliceToWorkers = make(map[slice]int)
}

func main() {
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

		if admissionReview.Request.Kind.Kind == "RayCluster" {
			klog.Info("Received review for RayCluster")
			response, err := mutateRayCluster(admissionReview)
			if err != nil {
				klog.Errorf("Failed to mutate ray cluster: %s", err)
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
		Addr:    ":443",
		Handler: mux,
	}

	if err := srv.ListenAndServeTLS(certPath, keyPath); err != nil {
		if err == http.ErrServerClosed {
			klog.Info("Server closed")
			return
		}
		klog.Error("Failed to start server")
	}
}