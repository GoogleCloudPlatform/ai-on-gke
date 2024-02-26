/*
Copyright 2024 The Kubernetes Authors.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package e2e_test

import (
	"e2e/test/util"
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	batchv1 "k8s.io/api/batch/v1"
	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/utils/ptr"
	runtimeclient "sigs.k8s.io/controller-runtime/pkg/client"
	jobset "sigs.k8s.io/jobset/api/jobset/v1alpha2"
)

const (
	jobsetCompletionTimeout = 10 * time.Minute
	nodeDeletionTimeout     = 5 * time.Minute
	testCaseLabel           = "test-case"
)

func TestTPUJobsets(t *testing.T) {
	cases := []struct {
		name   string
		config tpuConfig
	}{
		// v4
		{
			name: "v4-2x2x2-spot",
			config: tpuConfig{
				accelerator:  "tpu-v4-podslice",
				spot:         true,
				topoX:        2,
				topoY:        2,
				topoZ:        2,
				chipsPerNode: 4,
				sliceCount:   1,
			},
		},
		// v5e
		/*
			{
				name: "v5e-2x4-topo",
				config: tpuConfig{
					accelerator:  "tpu-v5-lite-podslice",
					topoX:        2,
					topoY:        4,
					chipsPerNode: 4,
					sliceCount:   2,
				},
			},
		*/
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			js := newJobset(c.name, c.config)
			err := client.Create(ctx, js)
			require.NoError(t, err)
			util.EnsureCleanup(t, func() {
				err := client.Delete(ctx, js)
				require.NoError(t, err)
			})

			// Example completed JobSet status:
			//
			// status:
			//   conditions:
			//   - lastTransitionTime: "2024-02-26T19:43:56Z"
			//     message: jobset completed successfully
			//     reason: AllJobsCompleted
			//     status: "True"
			//     type: Completed
			//   replicatedJobsStatus:
			//   - active: 0
			//     failed: 0
			//     name: testjob
			//     ready: 0
			//     succeeded: 1
			require.EventuallyWithT(t, func(t *assert.CollectT) {
				var createdJobset jobset.JobSet
				err := client.Get(ctx, runtimeclient.ObjectKeyFromObject(js), &createdJobset)
				assert.NoError(t, err, "Failed to get JobSet")
				assert.True(t, meta.IsStatusConditionTrue(createdJobset.Status.Conditions, string(jobset.JobSetCompleted)),
					"JobSet is not completed")
			}, jobsetCompletionTimeout, time.Second, "JobSet did not complete")

			require.EventuallyWithT(t, func(t *assert.CollectT) {
				var nodeList v1.NodeList
				err := client.List(ctx, &nodeList, runtimeclient.MatchingLabels{testCaseLabel: c.name})
				assert.NoError(t, err, "Failed to list Nodes")
				assert.Len(t, nodeList.Items, 0, "Nodes still exist with test case label")
			}, nodeDeletionTimeout, time.Second, "Nodes were not deleted after JobSet completed")
		})
	}
}

/*
https://cloud.google.com/tpu/docs/tpus-in-gke#v5e

Options for v5e:

For slice_count = 1, single host options:
1x1 (chips_per_node=1)
2x2 (chips_per_node=4)
2x4 (chips_per_node=8)

For slice_count >= 1, multi host options:
4x4   (chips_per_node=4)
4x8   (chips_per_node=4)
8x8   (chips_per_node=4)
8x16  (chips_per_node=4)
16x16 (chips_per_node=4)
*/

type tpuConfig struct {
	reservation string
	spot        bool

	accelerator  string
	sliceCount   int32
	chipsPerNode int32

	topoX int32
	topoY int32
	topoZ int32
}

func (t *tpuConfig) topology() string {
	if t.topoZ > 0 {
		return fmt.Sprintf("%dx%dx%d", t.topoX, t.topoY, t.topoZ)
	} else {
		return fmt.Sprintf("%dx%d", t.topoX, t.topoY)
	}
}

func (t *tpuConfig) nodesPerSlice() int32 {
	z := int32(1)
	if t.topoZ > 0 {
		z = t.topoZ
	}
	return t.topoX * t.topoY * z / t.chipsPerNode
}

func newJobset(name string, c tpuConfig) *jobset.JobSet {
	nodeSelectors := map[string]string{
		"cloud.google.com/gke-tpu-accelerator": c.accelerator,
		"cloud.google.com/gke-tpu-topology":    c.topology(),

		// Ensure each test case triggers its down node pool scale-up.
		testCaseLabel: name,
	}
	if c.reservation != "" {
		nodeSelectors["cloud.google.com/reservation-name"] = c.reservation
	}
	if c.spot {
		nodeSelectors["cloud.google.com/gke-spot"] = "true"
	}

	return &jobset.JobSet{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "jobset.sigs.k8s.io/v1alpha2",
			Kind:       "JobSet",
		},
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: "default",
			Annotations: map[string]string{
				"alpha.jobset.sigs.k8s.io/exclusive-topology": "cloud.google.com/gke-nodepool",
			},
		},
		Spec: jobset.JobSetSpec{
			FailurePolicy: &jobset.FailurePolicy{
				MaxRestarts: c.sliceCount,
			},
			ReplicatedJobs: []jobset.ReplicatedJob{
				{
					Name:     "testjob",
					Replicas: c.sliceCount,
					Template: batchv1.JobTemplateSpec{
						Spec: batchv1.JobSpec{
							Parallelism:  ptr.To(c.nodesPerSlice()),
							Completions:  ptr.To(c.nodesPerSlice()),
							BackoffLimit: ptr.To(c.nodesPerSlice()),
							Template: v1.PodTemplateSpec{
								Spec: v1.PodSpec{
									NodeSelector: nodeSelectors,
									Containers: []v1.Container{
										{
											Name:  "main",
											Image: "python:3.8",
											Ports: []v1.ContainerPort{
												{
													ContainerPort: 8471,
												},
												{
													ContainerPort: 8080,
												},
											},
											Command: []string{
												"bash",
												"-c",
												`pip install "jax[tpu]" -f https://storage.googleapis.com/jax-releases/libtpu_releases.html; env; python -c 'import jax; print("Device count: total =", jax.device_count(), " local =", jax.local_device_count())'`,
											},
											Args: []string{"echo", "job1"},
											Resources: v1.ResourceRequirements{
												Limits: v1.ResourceList{
													"google.com/tpu": resource.MustParse(fmt.Sprintf("%d", c.chipsPerNode)),
												},
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}
}
