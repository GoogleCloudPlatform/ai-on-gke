package cloud

import (
	"fmt"
	"testing"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

	jobset "sigs.k8s.io/jobset/api/jobset/v1alpha2"
)

func Test_tpuTopologyToNodeCount(t *testing.T) {
	cases := []struct {
		accel string
		topo  string
		count int
		err   bool
	}{
		{
			accel: "tpu-v4-podslice",
			topo:  "2x2x1",
			count: 1,
		},
		{
			accel: "tpu-v4-podslice",
			topo:  "2x2x2",
			count: 2,
		},
		{
			accel: "tpu-v5p-slice",
			topo:  "2x2x2",
			count: 2,
		},
		{
			accel: "tpu-v4-podslice",
			topo:  "2x2x4",
			count: 4,
		},
		{
			accel: "tpu-v5p-slice",
			topo:  "2x2x4",
			count: 4,
		},
		{
			accel: "tpu-v4-podslice",
			topo:  "2x4x4",
			count: 8,
		},
		{
			accel: "tpu-v5-lite-podslice",
			topo:  "2x4",
			count: 2,
		},
		{
			accel: "not-an-accel",
			topo:  "2x4",
			err:   true,
		},
		{
			accel: "tpu-v4-podslice",
			topo:  "not-a-topo",
			err:   true,
		},
	}

	for _, c := range cases {
		t.Run(c.accel+"_"+c.topo, func(t *testing.T) {
			count, err := tpuTopologyToNodeCount(c.accel, c.topo)
			if (err != nil) != c.err {
				t.Fatalf("error: expected: %v", c.err)
			}
			if exp, got := c.count, count; exp != got {
				t.Fatalf("count: expected: %v, got: %v", exp, got)
			}
		})
	}
}

func Test_tpuMachineType(t *testing.T) {
	cases := []struct {
		accel       string
		tpuRequest  int
		machineType string
		err         bool
	}{
		{
			accel:       "tpu-v4-podslice",
			tpuRequest:  4,
			machineType: "ct4p-hightpu-4t",
		},
		{
			accel:       "tpu-v5-lite-podslice",
			tpuRequest:  1,
			machineType: "ct5lp-hightpu-1t",
		},
		{
			accel:       "tpu-v5-lite-podslice",
			tpuRequest:  4,
			machineType: "ct5lp-hightpu-4t",
		},
		{
			accel:       "tpu-v5-lite-podslice",
			tpuRequest:  8,
			machineType: "ct5lp-hightpu-8t",
		},
		{
			accel:       "tpu-v5p-slice",
			tpuRequest:  4,
			machineType: "ct5p-hightpu-4t",
		},
		{
			accel:      "not-an-accel",
			tpuRequest: 4,
			err:        true,
		},
		{
			accel:      "tpu-v5p-slice",
			tpuRequest: -1,
			err:        true,
		},
	}

	for _, c := range cases {
		t.Run(fmt.Sprintf("%v_accel_%v_tpus", c.accel, c.tpuRequest), func(t *testing.T) {
			machineType, err := tpuMachineType(c.accel, c.tpuRequest)
			if (err != nil) != c.err {
				t.Fatalf("error: expected: %v", c.err)
			}
			if exp, got := c.machineType, machineType; exp != got {
				t.Fatalf("machineType: expected: %v, got: %v", exp, got)
			}
		})
	}
}

func TestPodToNodePoolName(t *testing.T) {
	var jobKey = "759730a97e4373f3a0ee12805db065e3a4a649a5"

	testCases := []struct {
		name          string
		pod           *corev1.Pod
		expectedName  string
		expectedError bool
	}{
		{
			name: "Missing JobSetName label",
			pod: &corev1.Pod{
				ObjectMeta: metav1.ObjectMeta{
					Name: "test-pod",
					Labels: map[string]string{
						jobset.JobKey: jobKey,
					},
				},
			},
			expectedError: true,
		},
		{
			name: "Missing JobKey label",
			pod: &corev1.Pod{
				ObjectMeta: metav1.ObjectMeta{
					Name: "test-pod",
					Labels: map[string]string{
						jobset.JobSetNameKey: "some-job-set-name",
					},
				},
			},
			expectedError: true,
		},
		{
			name: "jobset name less than 34 chars",
			pod: &corev1.Pod{
				ObjectMeta: metav1.ObjectMeta{
					Name: "test-pod",
					Labels: map[string]string{
						jobset.JobSetNameKey: "myjobset",
						jobset.JobKey:        jobKey,
					},
				},
			},
			expectedName: fmt.Sprintf("myjobset-%s", jobKey[:jobKeySuffixLength]),
		},
		{
			name: "jobset name more than 34 chars",
			pod: &corev1.Pod{
				ObjectMeta: metav1.ObjectMeta{
					Name: "test-pod",
					Labels: map[string]string{
						jobset.JobSetNameKey: "myjobset-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
						jobset.JobKey:        jobKey,
					},
				},
			},
			expectedName: fmt.Sprintf("%s-%s", "myjobset-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"[:maxJobSetPrefixLength], jobKey[:jobKeySuffixLength]),
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result, err := podToNodePoolName(tc.pod)

			if tc.expectedError && err == nil {
				t.Errorf("Expected error but got none")
			}
			if !tc.expectedError && err != nil {
				t.Errorf("Unexpected error: %v", err)
			}
			if result != tc.expectedName {
				t.Errorf("Expected node pool name %s, got %s", tc.expectedName, result)
			}
		})
	}
}
