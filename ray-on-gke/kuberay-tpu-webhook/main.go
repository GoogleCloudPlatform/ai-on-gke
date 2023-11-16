package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/rs/zerolog"
	ray "github.com/ray-project/kuberay/ray-operator/apis/ray/v1"

	admissionv1 "k8s.io/api/admission/v1"
	corev1 "k8s.io/api/core/v1"
)

// our representation of a pod slice
// not necessarily true that worker groups scheduled on 1 slice
type Slice struct {
	rayClusterName	string
	groupName	string
}

var (
	tpuResourceName = corev1.ResourceName("google.com/tpu")

	// map of ray cluster names to # of workers created in the slice
	sliceToWorkers map[Slice]int
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

// add TPU_WORKER_HOSTNAMES to containers in a ray cluster
func mutateRayCluster(
	admissionReview *admissionv1.AdmissionReview,
) (*admissionv1.AdmissionResponse, error) {
	raycluster, _ := extractRayCluster(admissionReview)
	patches := []map[string]interface{}{}

	for i := 0; i < len(raycluster.Spec.WorkerGroupSpecs); i++ {
		numWorkers := int(*raycluster.Spec.WorkerGroupSpecs[i].Replicas)

		// generate hostnames - TODO: make these hostnames DNS addressable with headless-svc
		workerGroupName := raycluster.Spec.WorkerGroupSpecs[i].GroupName
		serviceName := "headless-svc"
		hostNames := make([]string, numWorkers)
		for j := 0; j < numWorkers; j++ {
			hostNames[j] = fmt.Sprintf("%s-%d.%s", workerGroupName, j, serviceName)
		}
		joinedHostNames := strings.Join(hostNames, ",")

		// inject hostnames into ray worker pods
		for j := 0; j < len(raycluster.Spec.WorkerGroupSpecs[i].Template.Spec.Containers); j++ {
			container := raycluster.Spec.WorkerGroupSpecs[i].Template.Spec.Containers[j]
			if(containerRequestingTPUs(container)) {
				patch := map[string]interface{}{
					"op": "add",
				}
				path := fmt.Sprintf("/spec/workerGroupSpecs/%d/template/spec/containers/%d/env", i, j)
				value := corev1.EnvVar{
					Name:  "TPU_WORKER_HOSTNAMES",
					Value: joinedHostNames,
				}
				if len(container.Env) == 0 {
					patch["path"] = path
					patch["value"] = []corev1.EnvVar{value}
				} else {
					patch["path"] = fmt.Sprintf("%s/-", path)
					patch["value"] = value
				}
				patches = append(patches, patch)
			}
		}
	}
	patchBytes, _ := json.Marshal(patches)

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
func mutatePod(
	admissionReview *admissionv1.AdmissionReview,
) (*admissionv1.AdmissionResponse, error) {
	pod, _ := extractPod(admissionReview)

	// ray operator only sets GenerateName field - doesn't include random suffix until after admission request
	// use mapping of {cluster name, group name} -> # workers created to set TPU_WORKER_IDs
	clusterName := pod.Labels["ray.io/cluster"]
	groupName := pod.Labels["ray.io/group"]
	podSlice := Slice{clusterName, groupName}

	// assign to the next unique ID in the pod slice
	tpu_worker_id := sliceToWorkers[podSlice]
	sliceToWorkers[podSlice] += 1

	// create patch to tell pod how to modify environment
	patches := []map[string]interface{}{}

	// inject the TPU_WORKER_ID environment variable into the container reguesting TPUs
	for i := 0; i < len(pod.Spec.Containers); i++ {
		container := pod.Spec.Containers[i]
		if(containerRequestingTPUs(container)) {
			path := fmt.Sprintf("/spec/containers/%d/env", i)
			value := corev1.EnvVar{
				Name:  "TPU_WORKER_ID",
				Value: fmt.Sprint(tpu_worker_id),
			}
			patch := map[string]interface{}{
				"op": "add",
			}
			if(len(container.Env) == 0) {
				patch["path"] = path
				patch["value"] = []corev1.EnvVar{value}
			} else {
				patch["path"] = fmt.Sprintf("%s/-", path)
				patch["value"] = value
			}
			patches = append(patches, patch)
		}
	}

	patchBytes, _ := json.Marshal(patches)

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
	sliceToWorkers = make(map[Slice]int)
}

func main() {
	cert := "/etc/kuberay-tpu-webhook/tls/tls.crt"
	key := "/etc/kuberay-tpu-webhook/tls/tls.key"
	log := zerolog.New(os.Stdout).With().Timestamp().Logger()

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
			log.Debug().Msg("Received review for RayCluster")
			admissionReview.Response, _ = mutateRayCluster(admissionReview)
			responseBytes, _ := json.Marshal(admissionReview)
			fmt.Fprint(w, string(responseBytes))
			return
		}

		if admissionReview.Request.Kind.Kind == "Pod" {
			log.Debug().Msg("Received review for Pod")
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

	if err := srv.ListenAndServeTLS(cert, key); err != nil {
		if err == http.ErrServerClosed {
			log.Info().Msg("Server closed")
			return
		}
		log.Fatal().Err(err).Msg("Failed to start server")
	}
}