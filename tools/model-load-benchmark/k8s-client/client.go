package k8sclient

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"
	gcsfuse "tool/gcs-fuse"

	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
)

// Client struct to hold Kubernetes client and config information
type Client struct {
	KubeClient *kubernetes.Clientset
	Config     *rest.Config
}

// getKubeConfigPath determines the kubeconfig path based on the environment or default location
func getKubeConfigPath() string {
	// Check if the KUBECONFIG environment variable is set
	if kubeconfig := os.Getenv("KUBECONFIG"); kubeconfig != "" {
		return kubeconfig
	}

	// Fallback to default location in $HOME/.kube/config
	if home := homedir.HomeDir(); home != "" {
		return filepath.Join(home, ".kube", "config")
	}

	return ""
}

// loadConfigForCluster loads the kubeconfig for a specific cluster from the kubeconfig file
func loadConfigForCluster(kubeconfigPath, clusterName string) (*rest.Config, error) {
	// Load kubeconfig from file
	config, err := clientcmd.LoadFromFile(kubeconfigPath)
	if err != nil {
		return nil, fmt.Errorf("failed to load kubeconfig: %v", err)
	}

	// Look for the context with the provided clusterName
	_, exists := config.Contexts[clusterName]
	if !exists {
		return nil, fmt.Errorf("cluster %s not found in kubeconfig", clusterName)
	}

	// Set the current context to the found context
	config.CurrentContext = clusterName

	// Build the config for the specific context
	clientConfig := clientcmd.NewNonInteractiveClientConfig(*config, clusterName, &clientcmd.ConfigOverrides{}, nil)
	restConfig, err := clientConfig.ClientConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to create rest config: %v", err)
	}
	return restConfig, nil
}

// NewClient creates a new Kubernetes client based on a cluster name
func NewClient(clusterName string) (*Client, error) {
	kubeconfigPath := getKubeConfigPath()

	// Load the kubeconfig file
	config, err := loadConfigForCluster(kubeconfigPath, clusterName)
	if err != nil {
		return nil, fmt.Errorf("failed to load kubeconfig for cluster %s: %v", clusterName, err)
	}

	// Create the Kubernetes clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create kubernetes client: %v", err)
	}

	return &Client{
		KubeClient: clientset,
		Config:     config,
	}, nil
}

// GetNodes fetches a list of all nodes in the cluster
func (c *Client) GetNodes() ([]string, error) {
	nodes, err := c.KubeClient.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to list nodes: %v", err)
	}

	nodeNames := []string{}
	for _, node := range nodes.Items {
		nodeNames = append(nodeNames, node.Name)
	}

	return nodeNames, nil
}

// / DeployMistral7B creates the Mistral-7B deployment in the specified namespace
func (c *Client) DeployMistral7B() error {
	deployment := GetMistral7BDeployment()

	// Create the deployment in the default namespace
	_, err := c.KubeClient.AppsV1().Deployments(deployment.Namespace).Create(context.TODO(), deployment, metav1.CreateOptions{})
	if err != nil {
		return fmt.Errorf("failed to deploy mistral-7b: %v", err)
	}
	time.Sleep(10 * time.Second)
	fmt.Println("Mistral-7B deployment created successfully.")

	// Wait for the pod to be running and healthy
	labelSelector := fmt.Sprintf("app=%s", "mistral-7b")
	podList, err := c.KubeClient.CoreV1().Pods(deployment.Namespace).List(context.TODO(), metav1.ListOptions{LabelSelector: labelSelector})
	if err != nil {
		return fmt.Errorf("failed to list pods for deployment %s: %v", deployment.Name, err)
	}
	// Check if any pods are found
	if len(podList.Items) == 0 {
		return fmt.Errorf("no pods found for deployment %s", deployment.Name)
	}
	// Wait for the pods to be healthy
	for _, pod := range podList.Items {
		for i := 0; i < 90; i++ { // Retry for up to 30 seconds
			healthy, err := c.CheckPodHealth(deployment.Namespace, pod.Name)
			if err != nil {
				fmt.Printf("Health check failed for pod %s: %s\n", pod.Name, err)
			} else if healthy {
				fmt.Printf("Mistral-7B pod %s is healthy.\n", pod.Name)
				return nil
			}
			log.Printf("Current health status for pod %s: %v", pod.Name, healthy)
			time.Sleep(1 * time.Second)
		}
	}

	return fmt.Errorf("Mistral-7B pod did not become healthy in the expected time")
}

// DeployMeta creates the Meta deployment and service in the specified namespace
func (c *Client) DeployMeta(opt *gcsfuse.Options) error {
	namespace := "default"
	deploymentName := "meta-server"
	serviceName := "meta-service"

	// Delete existing deployment if it exists
	if err := c.KubeClient.AppsV1().Deployments(namespace).Delete(context.TODO(), deploymentName, metav1.DeleteOptions{}); err != nil && !errors.IsNotFound(err) {
		return fmt.Errorf("failed to delete existing deployment %s: %v", deploymentName, err)
	}
	fmt.Printf("Deleted existing deployment %s (if it existed).\n", deploymentName)
	time.Sleep(15 * time.Second)

	// Create the deployment
	deployment := GetMetaLlamaDeployment(opt)
	_, err := c.KubeClient.AppsV1().Deployments(namespace).Create(context.TODO(), deployment, metav1.CreateOptions{})
	if err != nil {
		return fmt.Errorf("failed to deploy meta: %v", err)
	}
	fmt.Println("Meta deployment created successfully.")

	// Delete existing service if it exists
	if err := c.KubeClient.CoreV1().Services(namespace).Delete(context.TODO(), serviceName, metav1.DeleteOptions{}); err != nil && !errors.IsNotFound(err) {
		return fmt.Errorf("failed to delete existing service %s: %v", serviceName, err)
	}
	fmt.Printf("Deleted existing service %s (if it existed).\n", serviceName)
	time.Sleep(10 * time.Second)
	// Create the service
	service := GetMetaLlamaService()
	_, err = c.KubeClient.CoreV1().Services(namespace).Create(context.TODO(), service, metav1.CreateOptions{})
	if err != nil {
		return fmt.Errorf("failed to create meta service: %v", err)
	}
	fmt.Println("Meta service created successfully.")

	// Wait for the pod to be running and healthy
	labelSelector := fmt.Sprintf("app=%s", "meta-server")
	podList, err := c.KubeClient.CoreV1().Pods(namespace).List(context.TODO(), metav1.ListOptions{LabelSelector: labelSelector})
	if err != nil {
		return fmt.Errorf("failed to list pods for deployment %s: %v", deployment.Name, err)
	}

	// Check if any pods are found
	if len(podList.Items) == 0 {
		return fmt.Errorf("no pods found for deployment %s", deployment.Name)
	}

	// Wait for the pods to be healthy
	for _, pod := range podList.Items {
		for i := 0; i < 90; i++ { // Retry for up to 90 seconds
			healthy, err := c.CheckPodHealth(namespace, pod.Name)
			if err != nil {
				fmt.Printf("Health check failed for pod %s: %s\n", pod.Name, err)
			} else if healthy {
				fmt.Printf("Meta pod %s is healthy.\n", pod.Name)
				break // Exit the loop if the pod is healthy
			}
			log.Printf("Current health status for pod %s: %v", pod.Name, healthy)
			time.Sleep(1 * time.Second)
		}
	}

	return nil
}

// CheckPodHealth checks the health of a specific pod by its name
func (c *Client) CheckPodHealth(namespace, podName string) (bool, error) {
	pod, err := c.KubeClient.CoreV1().Pods(namespace).Get(context.TODO(), podName, metav1.GetOptions{})
	if err != nil {
		return false, fmt.Errorf("failed to get pod %s: %v", podName, err)
	}

	// Check if the pod is in a running state
	if pod.Status.Phase != v1.PodRunning {
		return false, fmt.Errorf("pod %s is not running (current phase: %s)", podName, pod.Status.Phase)
	}

	// Initialize flags for readiness and liveness
	readinessHealthy := false
	livenessHealthy := true // Assume healthy unless proven otherwise

	// Check readiness conditions
	for _, condition := range pod.Status.Conditions {
		if condition.Type == v1.PodReady {
			readinessHealthy = condition.Status == v1.ConditionTrue
			break
		}
	}

	// Check container statuses for liveness
	for _, containerStatus := range pod.Status.ContainerStatuses {
		if containerStatus.Ready {
			continue // If container is ready, it is considered alive
		}

		// Check the last state for liveness probe failures
		if containerStatus.State.Waiting != nil {
			return false, fmt.Errorf("container %s in pod %s is waiting: %s", containerStatus.Name, podName, containerStatus.State.Waiting.Message)
		} else if containerStatus.State.Terminated != nil {
			return false, fmt.Errorf("container %s in pod %s has terminated: %s", containerStatus.Name, podName, containerStatus.State.Terminated.Message)
		} else if containerStatus.LastTerminationState.Terminated != nil {
			if containerStatus.LastTerminationState.Terminated.Reason == "Liveness probe failed" {
				livenessHealthy = false
				return false, fmt.Errorf("container %s in pod %s has failed liveness probe", containerStatus.Name, podName)
			}
		}
	}

	// Final health check
	if readinessHealthy && livenessHealthy {
		return true, nil
	}

	// Generate error messages based on probe status
	errorMessages := []string{}
	if !readinessHealthy {
		errorMessages = append(errorMessages, fmt.Sprintf("Pod %s is not ready", podName))
	}
	if !livenessHealthy {
		errorMessages = append(errorMessages, fmt.Sprintf("At least one container in pod %s is not alive", podName))
	}

	return false, fmt.Errorf("pod %q, unhealthy %q", podName, strings.Join(errorMessages, "; "))
}

func countSafetensorsFiles(bucketName string) (int, error) {
	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		return 0, err
	}
	defer client.Close()

	bucket := client.Bucket(bucketName)
	it := bucket.Objects(ctx, nil)

	var count int
	for {
		attr, err := it.Next()
		if err == storage.Done {
			break
		}
		if err != nil {
			return 0, err
		}
		if strings.HasSuffix(attr.Name, ".safetensors") {
			count++
		}
	}

	return count, nil
}
