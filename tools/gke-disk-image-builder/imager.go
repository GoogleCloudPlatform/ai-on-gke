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

// Package imager contains the library of the secondary disk image generator.
package imager

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/signal"
	"strings"
	"time"

	daisy "github.com/GoogleCloudPlatform/compute-daisy"
	"google.golang.org/api/compute/v1"
)

const (
	deviceName = "secondary-disk-image-disk"
)

// ImagePullAuthMechanism declares the contract on how to convert a struct into a string that is
// understandable to the script running on the VM instance for pulling the images.
type ImagePullAuthMechanism string

const (
	// None means that the script will not use any oauth access token. This image must be public
	// so that the script can pull it.
	None ImagePullAuthMechanism = "None"
	// ServiceAccountToken means that the script must use the oauth access token of the service account.
	// For more information refer to https://cloud.google.com/compute/docs/access/authenticate-workloads#applications
	ServiceAccountToken ImagePullAuthMechanism = "ServiceAccountToken"
)

// Request contains the required input for the disk image generation.
type Request struct {
	ImageName             string
	ImageFamilyName       string
	ProjectName           string
	JobName               string
	Zone                  string
	GCSPath               string
	MachineType           string
	DiskType              string
	DiskSizeGB            int64
	GCPOAuth              string
	Network               string
	Subnet                string
	ContainerImages       []string
	Timeout               time.Duration
	ImagePullAuth         ImagePullAuthMechanism
	ImageLabels           []string
	ServiceAccount        string
	StoreSnapshotCheckSum bool
}

func buildDiskStartupScript(req Request) (*os.File, error) {
	concreteStartupScript, err := os.CreateTemp("", fmt.Sprintf("%s-startup-script-", req.JobName))
	if err != nil {
		return nil, fmt.Errorf("unable to create a tmp file, err: %v", err)
	}
	startupScriptTemplate, err := os.Open("./script/startup.sh")
	if err != nil {
		return nil, fmt.Errorf("unable to open the startup template file, err: %v", err)
	}
	defer startupScriptTemplate.Close()
	if _, err = io.Copy(concreteStartupScript, startupScriptTemplate); err != nil {
		return nil, fmt.Errorf("unable to create the concrete startup file suceesfully, err: %v", err)
	}
	images := strings.Join(req.ContainerImages, " ")
	flags := fmt.Sprintf("\n\nunpack %t %s %s", req.StoreSnapshotCheckSum, req.ImagePullAuth, images)
	if _, err = concreteStartupScript.Write([]byte(flags)); err != nil {
		return nil, fmt.Errorf("umable to create concrete startup script: %v", err)
	}
	return concreteStartupScript, nil
}

func verifyDiskStartupScript(req Request) (*os.File, error) {
	verifyDiskStartupScript, err := os.CreateTemp("", fmt.Sprintf("%s-verify-startup-script-", req.JobName))
	if err != nil {
		return nil, fmt.Errorf("unable to create a tmp file, err: %v", err)
	}
	verifyDiskStartupScriptTemplate, err := os.Open("./script/verify.sh")
	if err != nil {
		return nil, fmt.Errorf("unable to open the startup template file, err: %v", err)
	}
	defer verifyDiskStartupScriptTemplate.Close()
	if _, err = io.Copy(verifyDiskStartupScript, verifyDiskStartupScriptTemplate); err != nil {
		return nil, fmt.Errorf("unable to create the verify disk startup file suceesfully, err: %v", err)
	}

	flags := fmt.Sprintf("\n\nverify_snapshots")
	if _, err = verifyDiskStartupScript.Write([]byte(flags)); err != nil {
		return nil, fmt.Errorf("umable to create verify disk startup script: %v", err)
	}

	return verifyDiskStartupScript, nil
}

func buildImageLabels(req Request) (map[string]string, error) {
	labels := make(map[string]string)
	for _, label := range req.ImageLabels {
		keyValue := strings.Split(label, "=")
		if len(keyValue) != 2 {
			return labels, fmt.Errorf("label: %v is not a valid key=value pair", label)
		}
		labels[keyValue[0]] = keyValue[1]
	}
	return labels, nil
}

// GenerateDiskImage generates the disk image according to the given request.
func GenerateDiskImage(ctx context.Context, req Request) error {
	startupScriptFile, err := buildDiskStartupScript(req)
	if err != nil {
		return err
	}
	imageLabels, err := buildImageLabels(req)
	if err != nil {
		return err
	}
	defer startupScriptFile.Close()
	defer os.Remove(startupScriptFile.Name())

	preloadDiskWorkflow := daisy.New()
	preloadDiskWorkflow.Name = req.JobName
	preloadDiskWorkflow.Project = req.ProjectName
	preloadDiskWorkflow.Zone = req.Zone
	preloadDiskWorkflow.GCSPath = req.GCSPath
	preloadDiskWorkflow.OAuthPath = req.GCPOAuth
	preloadDiskWorkflow.DefaultTimeout = req.Timeout.String()
	preloadDiskWorkflow.Sources = map[string]string{
		"startup.sh": startupScriptFile.Name(),
	}
	preloadDiskWorkflow.Steps = map[string]*daisy.Step{
		"create-disk": {
			CreateDisks: &daisy.CreateDisks{
				&daisy.Disk{
					Resource: daisy.Resource{
						ExactName: true,
					},
					Disk: compute.Disk{
						Name:   fmt.Sprintf("%s-disk", req.JobName),
						Type:   req.DiskType,
						SizeGb: req.DiskSizeGB,
					},
				},
			},
		},
		"create-instance": {
			CreateInstances: &daisy.CreateInstances{
				Instances: []*daisy.Instance{
					&daisy.Instance{
						InstanceBase: daisy.InstanceBase{
							Resource: daisy.Resource{
								ExactName: true,
							},
							StartupScript: "startup.sh",
						},
						Instance: compute.Instance{
							Name:        fmt.Sprintf("%s-instance", req.JobName),
							MachineType: fmt.Sprintf("zones/%s/machineTypes/%s", req.Zone, req.MachineType),
							ServiceAccounts: []*compute.ServiceAccount{
								&compute.ServiceAccount{
									Email: req.ServiceAccount,
									Scopes: []string{
										"https://www.googleapis.com/auth/cloud-platform",
									},
								},
							},
							NetworkInterfaces: []*compute.NetworkInterface{
								{
									Network:    req.Network,
									Subnetwork: req.Subnet,
								},
							},
							Disks: []*compute.AttachedDisk{
								&compute.AttachedDisk{
									AutoDelete: true,
									Boot:       true,
									Type:       "PERSISTENT",
									DeviceName: fmt.Sprintf("%s-bootable-disk", req.JobName),
									Mode:       "READ_WRITE",
									InitializeParams: &compute.AttachedDiskInitializeParams{
										DiskSizeGb:  req.DiskSizeGB,
										DiskType:    fmt.Sprintf("projects/%s/zones/%s/diskTypes/%s", req.ProjectName, req.Zone, req.DiskType),
										SourceImage: "projects/debian-cloud/global/images/debian-11-bullseye-v20230912",
									},
								},
								&compute.AttachedDisk{
									AutoDelete: true,
									Boot:       false,
									DiskSizeGb: req.DiskSizeGB,
									DeviceName: deviceName,
									Source:     fmt.Sprintf("%s-disk", req.JobName),
								},
							},
						},
					},
				},
			},
		},
		"wait-on-image-creation": {
			WaitForInstancesSignal: &daisy.WaitForInstancesSignal{
				&daisy.InstanceSignal{
					Name: fmt.Sprintf("%s-instance", req.JobName),
					SerialOutput: &daisy.SerialOutput{
						Port:         1,
						SuccessMatch: "Unpacking is completed",
						FailureMatch: []string{
							"startup-script-url exit status 1",
							"Failed to pull and unpack the image",
						},
					},
				},
			},
		},
		"detach-disk": {
			DetachDisks: &daisy.DetachDisks{
				&daisy.DetachDisk{
					Instance:   fmt.Sprintf("%s-instance", req.JobName),
					DeviceName: deviceName,
				},
			},
		},
		"create-image": {
			CreateImages: &daisy.CreateImages{
				Images: []*daisy.Image{
					&daisy.Image{
						ImageBase: daisy.ImageBase{
							Resource: daisy.Resource{
								NoCleanup: true,
								ExactName: true,
							},
						},
						Image: compute.Image{
							Name:       req.ImageName,
							SourceDisk: fmt.Sprintf("%s-disk", req.JobName),
							Family:     req.ImageFamilyName,
							Labels:     imageLabels,
						},
					},
				},
			},
		},
	}
	preloadDiskWorkflow.Dependencies = map[string][]string{
		"create-instance":        {"create-disk"},
		"wait-on-image-creation": {"create-instance"},
		"detach-disk":            {"wait-on-image-creation"},
		"create-image":           {"detach-disk"},
	}

	return run(ctx, preloadDiskWorkflow)
}

// VerifyDiskImage verifies the snapshots on the disk image by calculating the checksums and comparing them with those stored in snapshots.metadata file.
func VerifyDiskImage(ctx context.Context, req Request) error {
	startupScriptFile, err := verifyDiskStartupScript(req)
	if err != nil {
		return err
	}
	defer startupScriptFile.Close()
	defer os.Remove(startupScriptFile.Name())

	verifyDiskWorkflow := daisy.New()
	verifyDiskWorkflow.Name = req.JobName
	verifyDiskWorkflow.Project = req.ProjectName
	verifyDiskWorkflow.Zone = req.Zone
	verifyDiskWorkflow.GCSPath = req.GCSPath
	verifyDiskWorkflow.OAuthPath = req.GCPOAuth
	verifyDiskWorkflow.DefaultTimeout = req.Timeout.String()
	verifyDiskWorkflow.Sources = map[string]string{
		"verify.sh": startupScriptFile.Name(),
	}
	verifyDiskWorkflow.Steps = map[string]*daisy.Step{
		"create-disk": {
			CreateDisks: &daisy.CreateDisks{
				&daisy.Disk{
					Resource: daisy.Resource{
						ExactName: true,
					},
					Disk: compute.Disk{
						Name:   fmt.Sprintf("%s-disk", req.JobName),
						Type:   req.DiskType,
						SizeGb: req.DiskSizeGB,
						// Use the image to be verified to create a disk.
						SourceImage: req.ImageName,
					},
				},
			},
		},
		"create-instance": {
			CreateInstances: &daisy.CreateInstances{
				Instances: []*daisy.Instance{
					&daisy.Instance{
						InstanceBase: daisy.InstanceBase{
							Resource: daisy.Resource{
								ExactName: true,
							},
							StartupScript: "verify.sh",
						},
						Instance: compute.Instance{
							Name:        fmt.Sprintf("%s-instance", req.JobName),
							MachineType: fmt.Sprintf("zones/%s/machineTypes/%s", req.Zone, req.MachineType),
							NetworkInterfaces: []*compute.NetworkInterface{
								{
									Network:    req.Network,
									Subnetwork: req.Subnet,
								},
							},
							Disks: []*compute.AttachedDisk{
								&compute.AttachedDisk{
									AutoDelete: true,
									Boot:       true,
									Type:       "PERSISTENT",
									DeviceName: fmt.Sprintf("%s-bootable-disk", req.JobName),
									Mode:       "READ_WRITE",
									InitializeParams: &compute.AttachedDiskInitializeParams{
										DiskSizeGb:  req.DiskSizeGB,
										DiskType:    fmt.Sprintf("projects/%s/zones/%s/diskTypes/%s", req.ProjectName, req.Zone, req.DiskType),
										SourceImage: "projects/debian-cloud/global/images/debian-11-bullseye-v20230912",
									},
								},
								&compute.AttachedDisk{
									AutoDelete: true,
									Boot:       false,
									DiskSizeGb: req.DiskSizeGB,
									DeviceName: deviceName,
									Source:     fmt.Sprintf("%s-disk", req.JobName),
								},
							},
						},
					},
				},
			},
		},
		"wait-on-image-verification": {
			WaitForInstancesSignal: &daisy.WaitForInstancesSignal{
				&daisy.InstanceSignal{
					Name: fmt.Sprintf("%s-instance", req.JobName),
					SerialOutput: &daisy.SerialOutput{
						Port:         1,
						SuccessMatch: "Disk image verification succeeds",
						FailureMatch: []string{
							"Image verfication failure",
						},
					},
				},
			},
		},
		"detach-disk": {
			DetachDisks: &daisy.DetachDisks{
				&daisy.DetachDisk{
					Instance:   fmt.Sprintf("%s-instance", req.JobName),
					DeviceName: deviceName,
				},
			},
		},
	}
	verifyDiskWorkflow.Dependencies = map[string][]string{
		"create-instance":            {"create-disk"},
		"wait-on-image-verification": {"create-instance"},
		"detach-disk":                {"wait-on-image-verification"},
	}

	return run(ctx, verifyDiskWorkflow)
}

func run(ctx context.Context, w *daisy.Workflow) error {
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	var cancelError error
	go func(w *daisy.Workflow, e *error) {
		select {
		case <-c:
			*e = fmt.Errorf("Ctrl+C caught, cancelled by user")
			w.CancelWithReason((*e).Error())
		case <-w.Cancel:
		}
	}(w, &cancelError)

	err := w.Run(ctx)
	if cancelError != nil {
		return cancelError
	}
	return err
}
