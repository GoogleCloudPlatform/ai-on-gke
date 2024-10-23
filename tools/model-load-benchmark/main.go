package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	gcpClient "tool/gcp-client"
	gcsFuse "tool/gcs-fuse"
	k8sclient "tool/k8s-client"
)

func main() {
	ctx := context.Background()
	// Define command-line flags
	clusterName := flag.String("cluster-name", "gpu-dev-cluster", "The name of the GKE cluster")
	region := flag.String("region", "us-west4", "The region of the GKE cluster")
	gcsBucket := flag.String("gcs-bucket", "gs://vertex-model-garden-public-us/llama3.2/Llama-3.2-1B", "The GCS bucket URI for the model weights")

	// Parse the command-line flags
	flag.Parse()

	// Validate input
	if *clusterName == "" || *region == "" || *gcsBucket == "" {
		log.Fatalf("all flags (cluster-name, location, gcs-bucket) are required")
	}

	// Initialize GCP Client
	client, err := gcpClient.NewGCPClient(ctx)
	if err != nil {
		log.Fatalf("Failed to create GCP client: %v", err)
	}
	// Print the Project ID
	log.Printf("Project ID: %s\n", client.GetCreds().ProjectID)
	k8sClient, err := k8sclient.NewClient("gke_kunjanp-gke-dev-2_us-west4_gpu-dev-cluster")
	if err != nil {
		log.Fatalf("Failed to create k8s client: %v", err)
	}
	nodes, err := k8sClient.GetNodes()
	if err != nil {
		log.Fatalf("Failed to get k8s nodes: %v", err)
	}
	log.Printf("Nodes %v", nodes)
	mountOptions := &gcsFuse.MountOptions{
		FileCacheOptions: &gcsFuse.FileCacheOptions{
			EnableParallelDownloads:  true,
			ParallelDownloadsPerFile: 4,
			MaxParallelDownloads:     -1,
			DownloadChunkSizeMB:      3,
		},
	}

	perfOptions := &gcsFuse.PerfOptions{
		MountOptions: mountOptions,
		VolumeAttributes: &gcsFuse.VolumeAttributes{
			FileCacheCapacity: "-1"}, // Initialize with default or appropriate values
	}
	opt := &gcsFuse.Options{
		PerfOptions: perfOptions,
	}
	prettyJSON, err := json.MarshalIndent(opt.ToMap(), "", "  ")
	if err != nil {
		fmt.Println("Failed to generate JSON:", err)
		return
	}
	fmt.Println(string(prettyJSON))
	if err := k8sClient.DeployMeta(opt); err != nil {
		log.Fatalf("Failed to deploy pod %q", err)
	}
}
