package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"strconv"

	ray "github.com/ray-project/kuberay/ray-operator/apis/ray/v1"
	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
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
	tpuResourceName = corev1.ResourceName("google.com/tpu")
	certPath = "/etc/kuberay-tpu-webhook/tls/tls.crt"
	keyPath = "/etc/kuberay-tpu-webhook/tls/tls.key"

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

// check if request is for TPU multi-host
func isTPUMultiHost(topology string) bool {
	topologyVals :=  strings.Split(topology, "x")
	values := make([]int, len(topologyVals))
	for i := 0; i < len(values); i++ {
		dim, err := strconv.Atoi(topologyVals[i])
		if err != nil {
			klog.Fatalf("Invalid topology value: %s", err)
		}
		values[i] = dim
	}
	vms := 1 // number VMs = number chips / 4
	if len(values) == 3 {
		// TPU v4
		vms = max(values[0]*values[1]*values[2]/4, 1)
	} else if len(values) == 2 {
		// TPU v5e
		// slices with 8 chips can be single or multi host
		chips := values[0]*values[1]
		vms = max(chips/4, 1)
	}
	return (vms > 1)
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

func genDNSHostnames(workerGroupSpec ray.WorkerGroupSpec) string {
	numWorkers := int(*workerGroupSpec.Replicas)
	workerGroupName := workerGroupSpec.GroupName
	serviceName := "tpu-worker-group-svc" // TODO: get headless service from workergroup spec
	hostNames := make([]string, numWorkers)
	for j := 0; j < numWorkers; j++ {
		hostNames[j] = fmt.Sprintf("%s-%d.%s", workerGroupName, j, serviceName)
	}
	return strings.Join(hostNames, ",")
}

func injectHostnames(hostNames string, workerGroupSpec ray.WorkerGroupSpec, workerGroupIndex int, patches *[]patch) {
	for j := 0; j < len(workerGroupSpec.Template.Spec.Containers); j++ {
		container := workerGroupSpec.Template.Spec.Containers[j]
		if containerRequestingTPUs(container) {
			hostNamesPatch := patch {
				"op": "add",
			}
			path := fmt.Sprintf("/spec/workerGroupSpecs/%d/template/spec/containers/%d/env", workerGroupIndex, j)
			tpuWorkerHostNames := corev1.EnvVar{
				Name:  "TPU_WORKER_HOSTNAMES",
				Value: hostNames,
			}
			if len(container.Env) == 0 {
				hostNamesPatch["path"] = path
				hostNamesPatch["value"] = []corev1.EnvVar{tpuWorkerHostNames}
			} else {
				hostNamesPatch["path"] = fmt.Sprintf("%s/-", path)
				hostNamesPatch["value"] = tpuWorkerHostNames
			}
			*patches = append(*patches, hostNamesPatch)
		}
	}
}

// add TPU_WORKER_HOSTNAMES to containers in a ray cluster
func mutateRayCluster(admissionReview *admissionv1.AdmissionReview) (*admissionv1.AdmissionResponse, error) {
	raycluster, err := extractRayCluster(admissionReview)
	if err != nil {
		klog.Fatalf("Ray Cluster extraction failed: %s", err)
	}

	var patches []patch
	for i := 0; i < len(raycluster.Spec.WorkerGroupSpecs); i++ {
		workerGroupSpec := raycluster.Spec.WorkerGroupSpecs[i]
		if containerRequestingTPUs(workerGroupSpec.Template.Spec.Containers...) {
			topology := workerGroupSpec.Template.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]
			if isTPUMultiHost(topology) {
				joinedHostNames := genDNSHostnames(workerGroupSpec)
				injectHostnames(joinedHostNames, workerGroupSpec, i, &patches)
			}
		}
	}

	patchBytes, err := json.Marshal(patches)
	if err != nil {
		klog.Fatalf("Error serializing patches: %s", err)
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

// add TPU_WORKER_ID to pod environment
func mutatePod(admissionReview *admissionv1.AdmissionReview) (*admissionv1.AdmissionResponse, error) {
	pod, err := extractPod(admissionReview)
	if err != nil {
		klog.Fatalf("Pod extraction failed: %s", err)
	}

	var patches []patch
	// ray operator only sets GenerateName field - doesn't include random suffix until after admission request
	// use mapping of {cluster name, group name} -> # workers created to set TPU_WORKER_IDs
	clusterName := pod.Labels["ray.io/cluster"]
	groupName := pod.Labels["ray.io/group"]
	podSlice := slice{clusterName, groupName}
	topology := pod.Spec.NodeSelector["cloud.google.com/gke-tpu-topology"]

	// inject the TPU_WORKER_ID environment variable into the container requesting TPUs
	if containerRequestingTPUs(pod.Spec.Containers...) && isTPUMultiHost(topology) {
		// assign to the next unique ID in the pod slice
		tpu_worker_id := sliceToWorkers[podSlice]
		sliceToWorkers[podSlice] += 1
		for i := 0; i < len(pod.Spec.Containers); i++ {
			container := pod.Spec.Containers[i]
			if containerRequestingTPUs(container) {
				path := fmt.Sprintf("/spec/containers/%d/env", i)
				tpuWorkerID := corev1.EnvVar{
					Name:  "TPU_WORKER_ID",
					Value: fmt.Sprint(tpu_worker_id),
				}
				tpuName := corev1.EnvVar{
					Name:  "TPU_NAME",
					Value: fmt.Sprint(groupName),
				}
				idPatch, namePatch := patch{"op": "add",}, patch{"op": "add",}
				if len(container.Env) == 0 {
					idPatch["path"], namePatch["path"] = path, path
					idPatch["value"] = []corev1.EnvVar{tpuWorkerID}
					namePatch["value"] = []corev1.EnvVar{tpuName}
				} else {
					idPatch["path"], namePatch["path"] = fmt.Sprintf("%s/-", path), fmt.Sprintf("%s/-", path)
					idPatch["value"] = tpuWorkerID
					namePatch["value"] = tpuName
				}
				patches = append(patches, idPatch, namePatch)
			}
		}
	}

	patchBytes, err := json.Marshal(patches)
	if err != nil {
		klog.Fatalf("Error serializing patches: %s", err)
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
	mux.HandleFunc("/inject", func(w http.ResponseWriter, r *http.Request) {
		admissionReview := &admissionv1.AdmissionReview{}
		if err := json.NewDecoder(r.Body).Decode(admissionReview); err != nil {
			http.Error(w, "Error decoding request body", http.StatusBadRequest)
			return
		}

		if admissionReview.Request.Kind.Kind == "RayCluster" {
			klog.Info("Received review for RayCluster")
			admissionReview.Response, _ = mutateRayCluster(admissionReview)
			responseBytes, _ := json.Marshal(admissionReview)
			fmt.Fprint(w, string(responseBytes))
			return
		}

		if admissionReview.Request.Kind.Kind == "Pod" {
			klog.Info("Received review for Pod")
			admissionReview.Response, _ = mutatePod(admissionReview)
			responseBytes, _ := json.Marshal(admissionReview)
			fmt.Fprint(w, string(responseBytes))
			return
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