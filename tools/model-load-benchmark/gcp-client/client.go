package gcpClient

import (
	"context"
	"fmt"
	"os/exec"
	"sort"

	container "cloud.google.com/go/container/apiv1"
	"cloud.google.com/go/storage"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/option"
)

// GCPClient struct holds the Google Cloud client and project ID.
type GCPClient struct {
	ctx    context.Context
	creds  *google.Credentials
	client *container.ClusterManagerClient
}

// NewGCPClient creates a new GCPClient instance.
func NewGCPClient(ctx context.Context) (*GCPClient, error) {

	// Get the default credentials
	creds, err := google.FindDefaultCredentials(ctx)
	if err != nil {
		return nil, fmt.Errorf("unable to find default credentials: %v", err)
	}

	client := &GCPClient{
		ctx:   ctx,
		creds: creds,
	}
	if creds.ProjectID == "" {
		p := ""
		if p, err = GetProjectID(); err != nil || p == "" {
			return nil, fmt.Errorf("failed to get project id %v", err)
		}
		client.creds.ProjectID = p
	}
	// Create the GKE service
	gcpClient, err := container.NewClusterManagerClient(ctx, option.WithCredentials(creds))
	if err != nil {
		return nil, fmt.Errorf("failed to create GKE service: %v", err)
	}
	return &GCPClient{
		ctx:    ctx,
		creds:  creds,
		client: gcpClient,
	}, nil
}
func GetProjectID() (string, error) {
	// If ProjectID is still empty, try to fetch it from the gcloud configuration
	cmd := exec.Command("gcloud", "config", "get-value", "project")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("error getting project ID from gcloud: %v", err)
	}

	if string(output) == "" {
		fmt.Print("h")
	}
	return string(output), nil
}

// GetProjectID returns the project ID associated with the GCPClient.
func (g *GCPClient) GetCreds() *google.Credentials {
	return g.creds
}

func medianFileSizeInBucket(ctx context.Context, bucketName string) (float64, int64, error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to create client: %v", err)
	}
	defer client.Close()

	bucket := client.Bucket(bucketName)
	it := bucket.Objects(ctx, nil)

	var fileSizes []int64
	var fileCount int64

	for {
		attrs, err := it.Next()
		if err == storage.Done {
			break // End of iterator
		}
		if err != nil {
			return 0, 0, fmt.Errorf("failed to list objects: %v", err)
		}

		fileSizes = append(fileSizes, attrs.Size)
		fileCount++
	}

	if fileCount == 0 {
		return 0, 0, fmt.Errorf("no files found in the bucket")
	}

	// Sort file sizes to calculate the median
	sort.Slice(fileSizes, func(i, j int) bool {
		return fileSizes[i] < fileSizes[j]
	})

	// Calculate the median
	var medianSize float64
	if fileCount%2 == 0 {
		// Even number of files
		medianSize = float64(fileSizes[fileCount/2-1]+fileSizes[fileCount/2]) / 2
	} else {
		// Odd number of files
		medianSize = float64(fileSizes[fileCount/2])
	}

	return medianSize, fileCount, nil
}
