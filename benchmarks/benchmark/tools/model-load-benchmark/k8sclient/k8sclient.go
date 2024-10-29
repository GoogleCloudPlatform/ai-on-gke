package k8sclient

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
)

const (
	maxRetryInterval = 60 * time.Second
	failureThreshold = 10
)

// Client holds the k8s clientset
type Client struct {
	client      *kubernetes.Clientset
	ClusterName string
}

func InitClient() (*Client, error) {
	kubeconfig := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(
		clientcmd.NewDefaultClientConfigLoadingRules(),
		&clientcmd.ConfigOverrides{},
	)
	config, err := kubeconfig.ClientConfig()
	if err != nil {
		return nil, fmt.Errorf("failed to load Kubernetes config: %v", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create Kubernetes clientset: %v", err)

	}
	clusterName, _ := getClusterName()
	client := &Client{
		client:      clientset,
		ClusterName: clusterName,
	}

	return client, nil
}

func getClusterName() (string, error) {
	kubeconfigPath := filepath.Join(homedir.HomeDir(), ".kube", "config")
	if envPath := os.Getenv("KUBECONFIG"); envPath != "" {
		kubeconfigPath = envPath
	}
	kubeconfig, err := clientcmd.LoadFromFile(kubeconfigPath)
	if err != nil {
		return "", fmt.Errorf("failed to load kubeconfig: %w", err)
	}
	currentContext := kubeconfig.CurrentContext
	if currentContext == "" {
		return "", fmt.Errorf("no current context is set in kubeconfig")
	}
	contextConfig, exists := kubeconfig.Contexts[currentContext]
	if !exists {
		return "", fmt.Errorf("context %s not found in kubeconfig", currentContext)
	}
	clusterName := contextConfig.Cluster
	return clusterName, nil
}

func (k *Client) GetNodes() (*v1.NodeList, error) {
	nodes, err := k.client.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to get nodes: %v", err)
	}
	return nodes, nil
}

func (k *Client) PodExists(podName, namespace string) (bool, error) {
	_, err := k.client.CoreV1().Pods(namespace).Get(context.TODO(), podName, metav1.GetOptions{})
	if err != nil {
		if errors.IsNotFound(err) {
			return false, nil // Pod doesn't exist
		}
		return false, fmt.Errorf("failed to get pod: %v", err)
	}
	return true, nil
}

// DeletePod deletes given pod, if already being deleted, waits till it is deleted.
func (k *Client) DeletePod(pod *v1.Pod) error {
	exists, err := k.PodExists(pod.Name, pod.Namespace)
	if err != nil {
		return fmt.Errorf("failed to check if pod exists: %v", err)
	}
	if !exists {
		return nil
	}

	currentPod, err := k.client.CoreV1().Pods(pod.Namespace).Get(context.TODO(), pod.Name, metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get pod: %v", err)
	}
	// Delete the pod if it's not already being deleted
	if currentPod.DeletionTimestamp == nil {
		err = k.client.CoreV1().Pods(pod.Namespace).Delete(context.TODO(), pod.Name, metav1.DeleteOptions{})
		if err != nil {
			return fmt.Errorf("failed to delete pod %s in namespace %s: %v", pod.Name, pod.Namespace, err)
		}
	}

	// Wait for the pod to be deleted
	for {
		exists, err := k.PodExists(pod.Name, pod.Namespace)
		if err != nil {
			return fmt.Errorf("failed to check if pod exists: %v", err)
		}
		if !exists {
			return nil
		}
		time.Sleep(5 * time.Second)
	}
}

// GetPodNode waits until the pod is scheduled to a node or till a timeout.
func (k *Client) GetPodNode(pod *v1.Pod) error {
	timeout := 90 * time.Second
	interval := 5 * time.Second
	startTime := time.Now()

	for {
		updatedPod, err := k.client.CoreV1().Pods(pod.Namespace).Get(context.TODO(), pod.Name, metav1.GetOptions{})
		if err != nil {
			return fmt.Errorf("failed to get pod status: %v", err)
		}
		if updatedPod.Spec.NodeName != "" {
			return nil
		}
		if time.Since(startTime) >= timeout {
			return fmt.Errorf("90s timeout reached: pod %s in namespace %s is still not scheduled to any node", pod.Name, pod.Namespace)
		}
		time.Sleep(interval)
	}
}

// DeployAndMonitorPod deploys the pod and waits till all pod and its containers are ready
func (k *Client) DeployAndMonitorPod(pod *v1.Pod) (time.Duration, error) {
	maxPeriodSeconds := int32(5)
	maxInitialDelay := int32(0)
	for _, container := range pod.Spec.Containers {
		if container.ReadinessProbe != nil && container.ReadinessProbe.PeriodSeconds > maxPeriodSeconds {
			maxPeriodSeconds = container.ReadinessProbe.PeriodSeconds
			maxInitialDelay = max(maxInitialDelay, container.ReadinessProbe.InitialDelaySeconds)
		}
	}
	// Create the pod
	namespace := "default"
	if pod.GetNamespace() != "" {
		namespace = pod.GetNamespace()
	} else {
		pod.SetNamespace(namespace)
	}
	err := k.DeletePod(pod)
	if err != nil {
		return -1, fmt.Errorf("failed to delete existing pod: %v", err)
	}
	pod, err = k.client.CoreV1().Pods(namespace).Create(context.TODO(), pod, metav1.CreateOptions{})
	if err != nil {
		return -1, fmt.Errorf("failed to create pod: %v", err)
	}
	// wait for pod to be placed on node
	err = k.GetPodNode(pod)
	if err != nil {
		return -1, fmt.Errorf("failed to deploy pod: %v", err)
	}
	startTime := time.Now()
	defer k.DeletePod(pod)
	time.Sleep(time.Duration(maxInitialDelay) * time.Second)
	// Monitor the pod status with exponential backoff
	retryInterval := time.Duration(maxPeriodSeconds) * time.Second
	failureCount := 0
	for {
		pod, err := k.client.CoreV1().Pods("default").Get(context.TODO(), pod.Name, metav1.GetOptions{})
		if err != nil {
			return -1, fmt.Errorf("failed to get pod status: %v", err)
		}

		// Check if all containers are ready
		allContainersReady := true
		for _, containerStatus := range pod.Status.ContainerStatuses {
			if !containerStatus.Ready {
				allContainersReady = false
				break
			}
		}

		if pod.Status.Phase == v1.PodRunning && allContainersReady {
			endTime := time.Now()
			return endTime.Sub(startTime), nil
		}

		switch pod.Status.Phase {
		case v1.PodSucceeded:
			endTime := time.Now()
			return endTime.Sub(startTime), nil
		case v1.PodFailed:
			return -1, fmt.Errorf("pod %s failed: %s", pod.Name, pod.Status.Reason)
		}

		// Exponential backoff with a maximum interval
		time.Sleep(retryInterval)
		retryInterval *= 2
		if retryInterval > maxRetryInterval && retryInterval > time.Duration(maxPeriodSeconds)*time.Second {
			retryInterval = maxRetryInterval
		}
		failureCount++
		if failureCount > failureThreshold {
			break
		}
	}
	return -1, fmt.Errorf("pod monitoring timeout, not all containers ready")
}
