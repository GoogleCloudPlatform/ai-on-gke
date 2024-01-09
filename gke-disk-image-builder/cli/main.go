// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// 	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package main contains the CLI of the secondary disk image generator.
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"strings"
	"time"

	builder "github.com/GoogleCloudPlatform/ai-on-gke/gke-disk-image-builder"
)

type stringSlice []string

func (s *stringSlice) String() string {
	return "my string representation"
}

func (s *stringSlice) Set(value string) error {
	*s = append(*s, value)
	return nil
}

func main() {
	var containerImages stringSlice
	projectName := flag.String("project-name", "", "name of a gcp project where the script will be run")
	imageName := flag.String("image-name", "", "name of the image that will be generated")
	jobName := flag.String("job-name", "secondary-disk-image", "name of the workflow job; no more than 50 characters")
	zone := flag.String("zone", "", "zone where the resources will be used to create the image creator resources")
	gcsPath := flag.String("gcs-path", "", "gcs location to dump the logs")
	machineType := flag.String("machine-type", "n2-standard-16", "GCE instance machine type to generate the disk image")
	diskType := flag.String("disk-type", "pd-ssd", "disk type to generate the disk image")
	diskSizeGb := flag.Int64("disk-size-gb", 60, "disk size to unpack container images")
	gcpOAuth := flag.String("gcp-oauth", "", "path to GCP service account credential file")
	imagePullAuth := flag.String("image-pull-auth", "None", "auth mechanism to pull the container image, valid values: [None, ServiceAccountToken].\nNone means that the images are publically available and no authentication is required to pull them.\nServiceAccountToken means the service account oauth token will be used to pull the images.\nFor more information refer to https://cloud.google.com/compute/docs/access/authenticate-workloads#applications")
	timeout := flag.String("timeout", "20m", "Default timout for each step, defaults to 20m")
	network := flag.String("network", "default", "VPC network to be used by GCE resources used for disk image creation.")
	subnet := flag.String("subnet", "default", "subnet to be used by GCE resources used for disk image creation.")
	flag.Var(&containerImages, "container-image", "container image to include in the disk image. This flag can be specified multiple times")

	flag.Parse()
	ctx := context.Background()

	td, err := time.ParseDuration(*timeout)
	if err != nil {
		log.Panicf("invalid argument, timeout: %v, err: %v", timeout, err)
	}

	if len(*jobName) >= 50 {
		log.Panicf("invalid argument, job-name: %v should be less than 50 characters, got: %v", *jobName, len(*jobName))
	}

	var auth builder.ImagePullAuthMechanism
	switch *imagePullAuth {
	case "":
		auth = builder.None
	case "None":
		auth = builder.None
	case "ServiceAccountToken":
		auth = builder.ServiceAccountToken
	default:
		log.Panicf("Please specify a valid value for the flag --image-pull-auth, valid values are [None, ServiceAccountToken]")
	}

	req := builder.Request{
		ImageName:       *imageName,
		ProjectName:     *projectName,
		JobName:         *jobName,
		Zone:            *zone,
		GCSPath:         *gcsPath,
		MachineType:     *machineType,
		DiskType:        *diskType,
		DiskSizeGB:      *diskSizeGb,
		GCPOAuth:        *gcpOAuth,
		Network:         fmt.Sprintf("projects/%s/global/networks/%s", *projectName, *network),
		Subnet:          fmt.Sprintf("projects/%s/regions/%s/subnetworks/%s", *projectName, regionForZone(*zone), *subnet),
		ContainerImages: containerImages,
		Timeout:         td,
		ImagePullAuth:   auth,
	}

	if err = builder.GenerateDiskImage(ctx, req); err != nil {
		log.Panicf("unable to generate disk image: %v", err)
	}
	fmt.Printf("Image has successfully been created at: projects/%s/global/images/%s\n", req.ProjectName, req.ImageName)
}

// regionForZone returns the region for a given zone (e.g. "us-central1-c" -> "us-central1").
func regionForZone(zone string) string {
	p := strings.Split(zone, "-")
	return strings.Join(p[:len(p)-1], "-")
}
