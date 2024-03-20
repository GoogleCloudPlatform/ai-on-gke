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
	"regexp"
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

var (
	gcpResourceNameRegex = regexp.MustCompile("^[a-z]([-a-z0-9]*[a-z0-9])?$")
)

func main() {
	var containerImages stringSlice
	var imageLabels stringSlice
	projectName := flag.String("project-name", "", "name of a gcp project where the script will be run")
	imageName := flag.String("image-name", "", "name of the image that will be generated")
	imageFamilyName := flag.String("image-family-name", "secondary-disk-image", "name of the image family associated with the created disk image")
	jobName := flag.String("job-name", "secondary-disk-image", "name of the workflow job; no more than 50 characters")
	zone := flag.String("zone", "", "zone where the resources will be used to create the image creator resources")
	gcsPath := flag.String("gcs-path", "", "gcs location to dump the logs")
	machineType := flag.String("machine-type", "n2-standard-16", "GCE instance machine type to generate the disk image")
	serviceAccount := flag.String("service-account", "default", "Service Account email assigned to the GCE instance used for creating the disk image.")
	diskType := flag.String("disk-type", "pd-ssd", "disk type to generate the disk image")
	diskSizeGb := flag.Int64("disk-size-gb", 60, "disk size to unpack container images")
	gcpOAuth := flag.String("gcp-oauth", "", "path to GCP service account credential file")
	imagePullAuth := flag.String("image-pull-auth", "None", "auth mechanism to pull the container image, valid values: [None, ServiceAccountToken].\nNone means that the images are publically available and no authentication is required to pull them.\nServiceAccountToken means the service account oauth token will be used to pull the images.\nFor more information refer to https://cloud.google.com/compute/docs/access/authenticate-workloads#applications")
	timeout := flag.String("timeout", "20m", "Default timout for each step, defaults to 20m")
	network := flag.String("network", "default", "VPC network to be used by GCE resources used for disk image creation.")
	subnet := flag.String("subnet", "default", "subnet to be used by GCE resources used for disk image creation.")
	storeSnapshotCheckSum := flag.Bool("store-snapshot-checksum", true, "calculate and store checksums of every snapshot directory.")
	verifyOnly := flag.Bool("verify-only", false, "Only verifies the disk image provided in image-name, and does not generate any image.")
	flag.Var(&imageLabels, "image-labels", "labels tagged to the disk image. This flag can be specified multiple times. The accepted format is `--image-labels=key=val`.")
	flag.Var(&containerImages, "container-image", "container image to include in the disk image. This flag can be specified multiple times")

	flag.Parse()
	ctx := context.Background()

	td, err := time.ParseDuration(*timeout)
	if err != nil {
		log.Panicf("invalid argument, timeout: %v, err: %v", timeout, err)
	}

	// GCP resources naming convention: https://cloud.google.com/compute/docs/naming-resources
	if len(*jobName) >= 50 {
		log.Panicf("invalid argument, job-name: %v should be less than 50 characters, got: %v", *jobName, len(*jobName))
	}
	if !gcpResourceNameRegex.MatchString(*jobName) {
		log.Panicf("invalid argument, job-name: %v must conform to `^[a-z]([-a-z0-9]*[a-z0-9])?`")
	}
	if len(*imageFamilyName) >= 64 {
		log.Panicf("invalid argument, image-family-name: %v should be less than 64 characters, got: %v", *imageFamilyName, len(*imageFamilyName))
	}
	if !gcpResourceNameRegex.MatchString(*imageFamilyName) {
		log.Panicf("invalid argument, image-family-name: %v must conform to `^[a-z]([-a-z0-9]*[a-z0-9])?`", *imageFamilyName)
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
		ImageName:             *imageName,
		ImageFamilyName:       *imageFamilyName,
		ProjectName:           *projectName,
		JobName:               *jobName,
		Zone:                  *zone,
		GCSPath:               *gcsPath,
		MachineType:           *machineType,
		ServiceAccount:        *serviceAccount,
		DiskType:              *diskType,
		DiskSizeGB:            *diskSizeGb,
		GCPOAuth:              *gcpOAuth,
		Network:               fmt.Sprintf("projects/%s/global/networks/%s", *projectName, *network),
		Subnet:                fmt.Sprintf("projects/%s/regions/%s/subnetworks/%s", *projectName, regionForZone(*zone), *subnet),
		ContainerImages:       containerImages,
		Timeout:               td,
		ImagePullAuth:         auth,
		ImageLabels:           imageLabels,
		StoreSnapshotCheckSum: *storeSnapshotCheckSum,
	}

	if *verifyOnly {
		if err = builder.VerifyDiskImage(ctx, req); err != nil {
			log.Panicf("Image verification fails. The images/snapshots preloaded might be broken: %v", err)
		}
		fmt.Printf("Image at projects/%s/global/images/%s\n has been verified and all container images and snapshots are valid.", req.ProjectName, req.ImageName)
		return
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
