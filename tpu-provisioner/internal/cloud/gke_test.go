package cloud

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"testing"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"

	"github.com/google/go-cmp/cmp"
	container "google.golang.org/api/container/v1beta1"
	"google.golang.org/api/googleapi"
	"k8s.io/apimachinery/pkg/api/resource"
	jobset "sigs.k8s.io/jobset/api/jobset/v1alpha2"
)

func TestEnsureNodePoolForPod(t *testing.T) {
	svc := &mockGKEService{
		creates:   make(map[string]int),
		deletes:   make(map[string]int),
		nodePools: make(map[string]*container.NodePool),
	}
	clusterCtx := GKEContext{
		ProjectID:              "test-project",
		ClusterLocation:        "us-east5",
		Cluster:                "test-cluster",
		NodeZone:               "us-east5-a",
		NodeServiceAccount:     "test-sa@test-project.iam.gserviceaccount.com",
		NodeAdditionalNetworks: "",
		NodeSecondaryDisk:      "test-disk",
		NodeTags:               []string{"foo", "bar"},
		PodToNodeLabels:        nil,
		NodeSecureBoot:         true,
		ForceOnDemand:          false,
	}
	rec := &mockEventRecorder{}
	gke := &GKE{
		NodePools:      svc,
		ClusterContext: clusterCtx,
		Recorder:       rec,
	}

	cases := []struct {
		name          string
		pod           podBuild
		expNPCreation bool
		expNPDeletion bool
	}{
		{
			name:          "simple creation",
			pod:           podBuild{},
			expNPCreation: true,
		},
		{
			name:          "duplicate pod",
			pod:           podBuild{},
			expNPCreation: false,
		},
		{
			name: "same pod - with spot now",
			pod: podBuild{
				additionalSelector: map[string]string{
					"cloud.google.com/gke-spot": "true",
				},
			},
			expNPCreation: false,
			expNPDeletion: true,
		},
		{
			name: "same pod - with spot - 2nd pass",
			pod: podBuild{
				additionalSelector: map[string]string{
					"cloud.google.com/gke-spot": "true",
				},
			},
			expNPCreation: true,
			expNPDeletion: false,
		},
		{
			name: "different jobset",
			pod: podBuild{
				jobsetNameSuffix: "-2",
			},
			expNPCreation: true,
		},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			pod := buildPod(c.pod)
			npName, err := podToNodePoolName(pod)
			if err != nil {
				t.Fatalf("podToNodePoolName(): %v", err)
			}

			createsBefore := svc.creates[npName]
			deletesBefore := svc.deletes[npName]

			err = gke.EnsureNodePoolForPod(pod, "test")
			if c.expNPDeletion {
				if !errors.Is(err, ErrNodePoolDeletedToBeRecreated) {
					t.Fatalf("expected ErrNodePoolDeletedToBeRecreated, got: %v", err)
				}
			} else {
				if err != nil {
					t.Fatalf("EnsureNodePoolForPod(%v): %v", pod.Name, err)
				}
			}

			createsAfter := svc.creates[npName]
			deletesAfter := svc.deletes[npName]

			if c.expNPCreation {
				if createsAfter-createsBefore != 1 {
					t.Fatalf("expected create for node pool %q, got none", npName)
				}
			}
			if c.expNPDeletion {
				if deletesAfter-deletesBefore != 1 {
					t.Fatalf("expected delete for node pool %q, got none", npName)
				}
			}
		})
	}
}

type mockEventRecorder struct{}

func (r *mockEventRecorder) Event(object runtime.Object, eventtype, reason, message string) {}
func (r *mockEventRecorder) Eventf(object runtime.Object, eventtype, reason, messageFmt string, args ...interface{}) {
}
func (r *mockEventRecorder) AnnotatedEventf(object runtime.Object, annotations map[string]string, eventtype, reason, messageFmt string, args ...interface{}) {
}

type mockGKEService struct {
	creates   map[string]int
	deletes   map[string]int
	nodePools map[string]*container.NodePool
}

func (g *mockGKEService) Get(ctx context.Context, name string) (*container.NodePool, error) {
	np, ok := g.nodePools[name]
	if !ok {
		return nil, &googleapi.Error{
			Code: http.StatusNotFound,
		}
	}
	return np, nil
}

func (g *mockGKEService) List(ctx context.Context) (*container.ListNodePoolsResponse, error) {
	var resp container.ListNodePoolsResponse
	for _, np := range g.nodePools {
		resp.NodePools = append(resp.NodePools, np)
	}
	return &resp, nil
}

func (g *mockGKEService) Create(ctx context.Context, req *container.CreateNodePoolRequest, callbacks OpCallbacks) error {
	_, alreadyExists := g.nodePools[req.NodePool.Name]
	if alreadyExists {
		return &googleapi.Error{
			Code: http.StatusConflict,
		}
	}
	g.nodePools[req.NodePool.Name] = req.NodePool
	g.creates[req.NodePool.Name]++
	return nil
}

func (g *mockGKEService) Delete(ctx context.Context, name string, callbacks OpCallbacks) error {
	_, ok := g.nodePools[name]
	if !ok {
		return &googleapi.Error{
			Code: http.StatusNotFound,
		}
	}
	delete(g.nodePools, name)
	g.deletes[name]++
	return nil
}

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
			topo:  "1x1",
			count: 1,
		},
		{
			accel: "tpu-v5-lite-podslice",
			topo:  "2x4",
			count: 2,
		},
		{
			accel: "tpu-v6e-slice",
			topo:  "1x1",
			count: 1,
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
		{
			accel: "tpu-v6e-slice",
			topo:  "16x16",
			count: 64,
		},
		{
			accel: "tpu-v6e-slice",
			topo:  "1x1x1",
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

func TestNodePoolForPod(t *testing.T) {
	tests := []struct {
		desc       string
		gkeContext GKEContext
		pod        podBuild
		want       *container.NodePool
	}{
		{
			desc: "simple case",
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "simple case 1x1 topology",
			pod: podBuild{
				selector: map[string]string{
					"cloud.google.com/gke-tpu-accelerator": "tpu-v5-lite-podslice",
					"cloud.google.com/gke-tpu-topology":    "1x1",
				},
				tpuResource: "1",
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType:            "ct5lp-hightpu-1t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  1,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				PlacementPolicy:   &container.PlacementPolicy{},
				Name:              "jobset-test-rando",
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "spot",
			pod: podBuild{
				additionalSelector: map[string]string{
					"cloud.google.com/gke-spot": "true",
				},
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
					Spot:                   true,
					Taints: []*container.NodeTaint{
						{Effect: "NO_SCHEDULE", Key: "cloud.google.com/gke-spot", Value: "true"},
					},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc:       "spot with forced on demand",
			gkeContext: GKEContext{ForceOnDemand: true},
			pod: podBuild{
				additionalSelector: map[string]string{
					"cloud.google.com/gke-spot": "true",
				},
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
					Spot:                   false,
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "pod with reservation selector",
			pod: podBuild{
				additionalSelector: map[string]string{"cloud.google.com/reservation-name": "tpu-rsv"},
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType: "ct5p-hightpu-4t",
					ReservationAffinity: &container.ReservationAffinity{
						ConsumeReservationType: "SPECIFIC_RESERVATION",
						Key:                    "compute.googleapis.com/reservation-name",
						Values:                 []string{"tpu-rsv"},
					},
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "pod with cross-project reservation selector",
			pod: podBuild{
				additionalSelector: map[string]string{
					"cloud.google.com/reservation-name":    "tpu-rsv",
					"cloud.google.com/reservation-project": "tpu-rsv-project",
				},
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType: "ct5p-hightpu-4t",
					ReservationAffinity: &container.ReservationAffinity{
						ConsumeReservationType: "SPECIFIC_RESERVATION",
						Key:                    "compute.googleapis.com/reservation-name",
						Values:                 []string{"projects/tpu-rsv-project/reservations/tpu-rsv"},
					},
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "pod with reservation selector but on demand is forced",
			pod: podBuild{
				additionalSelector: map[string]string{"cloud.google.com/reservation-name": "tpu-rsv"},
			},
			gkeContext: GKEContext{ForceOnDemand: true},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType:            "ct5p-hightpu-4t",
					ReservationAffinity:    nil,
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "pod with disabling ICI resiliency selector",
			pod: podBuild{
				additionalSelector: map[string]string{"cloud.google.com/gke-tpu-ici-resiliency": "false"},
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
						"cloud.google.com/gke-tpu-ici-resiliency":     "false",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc:       "pod with secondary boot disk",
			gkeContext: GKEContext{NodeSecondaryDisk: "projects/my-gcp-project/global/images/my-disk-image"},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
					SecondaryBootDisks: []*container.SecondaryBootDisk{
						{
							DiskImage: "projects/my-gcp-project/global/images/my-disk-image",
							Mode:      "CONTAINER_IMAGE_CACHE",
						},
					},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "pod with location hint node selector",
			pod: podBuild{
				additionalSelector: map[string]string{"cloud.google.com/gke-location-hint": "test-location-hint"},
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
						"cloud.google.com/gke-location-hint":          "test-location-hint",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "labels to copy from pod to node",
			gkeContext: GKEContext{
				PodToNodeLabels: []string{"should-be-copied"},
			},
			pod: podBuild{
				additionalLabels: map[string]string{
					"should-be-copied":     "val-a",
					"should-not-be-copied": "val-b",
				},
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
						"should-be-copied":                            "val-a",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "labels to copy from pod to node by annotation",
			pod: podBuild{
				additionalLabels: map[string]string{
					"copy-me":      "val-x",
					"dont-copy-me": "val-y",
				},
				additionalAnnotations: map[string]string{
					"tpu-provisioner.cloud.google.com/copy-labels": "copy-me",
				},
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
						"copy-me": "val-x",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
		{
			desc: "additional node networks configured in cluster context",
			gkeContext: GKEContext{
				NodeAdditionalNetworks: "network-1:subnet-1, network-2:subnet-2",
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
				NetworkConfig: &container.NodeNetworkConfig{
					AdditionalNodeNetworkConfigs: []*container.AdditionalNodeNetworkConfig{
						{
							Network:    "network-1",
							Subnetwork: "subnet-1",
						},
						{
							Network:    "network-2",
							Subnetwork: "subnet-2",
						},
					},
				},
			},
		},
		{
			desc: "pod requesting additional node networks",
			gkeContext: GKEContext{
				NodeAdditionalNetworks: "should-be-overriden-1:should-be-overriden-2",
			},
			pod: podBuild{
				additionalAnnotations: map[string]string{
					"tpu-provisioner.cloud.google.com/additional-node-networks": "network-1:subnet-1, network-2:subnet-2",
				},
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType:            "ct5p-hightpu-4t",
					ShieldedInstanceConfig: &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
				NetworkConfig: &container.NodeNetworkConfig{
					AdditionalNodeNetworkConfigs: []*container.AdditionalNodeNetworkConfig{
						{
							Network:    "network-1",
							Subnetwork: "subnet-1",
						},
						{
							Network:    "network-2",
							Subnetwork: "subnet-2",
						},
					},
				},
			},
		},
		{
			desc: "confidential disk configured in cluster context",
			gkeContext: GKEContext{
				NodeConfidentialStorage: true,
				NodeDiskType:            "hyperdisk-balanced",
				NodeBootDiskKMSKey:      "my-kms-key",
			},
			want: &container.NodePool{
				Config: &container.NodeConfig{
					Labels: map[string]string{
						"google.com/nodepool-manager":                 "tpu-provisioner",
						"google.com/tpu-provisioner-jobset-name":      "jobset-test",
						"google.com/tpu-provisioner-jobset-namespace": "default",
						"google.com/tpu-provisioner-parent-kind":      "job",
						"google.com/tpu-provisioner-parent-name":      "jobset-test-job-1-0",
						"google.com/tpu-provisioner-parent-namespace": "default",
					},
					MachineType:               "ct5p-hightpu-4t",
					ShieldedInstanceConfig:    &container.ShieldedInstanceConfig{EnableIntegrityMonitoring: true},
					EnableConfidentialStorage: true,
					BootDiskKmsKey:            "my-kms-key",
					DiskType:                  "hyperdisk-balanced",
				},
				InitialNodeCount:  512,
				Locations:         []string{""},
				Management:        &container.NodeManagement{AutoRepair: true, AutoUpgrade: false},
				MaxPodsConstraint: &container.MaxPodsConstraint{MaxPodsPerNode: 15},
				Name:              "jobset-test-rando",
				PlacementPolicy:   &container.PlacementPolicy{TpuTopology: "8x16x16", Type: "COMPACT"},
				UpgradeSettings:   &container.UpgradeSettings{MaxSurge: 1},
			},
		},
	}
	for _, tc := range tests {
		t.Run(tc.desc, func(t *testing.T) {
			gke := &GKE{
				ClusterContext: tc.gkeContext,
			}
			pod := buildPod(tc.pod)
			got, err := gke.nodePoolForPod(pod)
			if err != nil {
				t.Errorf("Got error: %v", err)
			}

			// Populating a hash in test cases is a hassle, so we will just check for existance.
			gotHash := got.Config.Labels[LabelNodePoolHash]
			t.Logf("Node pool hash: %s", gotHash)
			if gotHash == "" {
				t.Errorf("Node pool hash should be populated")
			}
			delete(got.Config.Labels, LabelNodePoolHash)

			if diff := cmp.Diff(tc.want, got); diff != "" {
				t.Errorf("TestNodePoolForPod() return unexpected node pool, diff (-want +got): \n%s", diff)
			}
		})
	}
}

type podBuild struct {
	jobsetNameSuffix      string
	additionalLabels      map[string]string
	additionalAnnotations map[string]string
	selector              map[string]string
	additionalSelector    map[string]string
	tpuResource           string
}

func buildPod(b podBuild) *corev1.Pod {
	trueVar := true

	if b.selector == nil {
		b.selector = map[string]string{
			"cloud.google.com/gke-tpu-accelerator": "tpu-v5p-slice",
			"cloud.google.com/gke-tpu-topology":    "8x16x16",
		}
	}

	if b.tpuResource == "" {
		b.tpuResource = "4"
	}

	pod := &corev1.Pod{
		TypeMeta: metav1.TypeMeta{
			APIVersion: "v1",
			Kind:       "Pod",
		},
		ObjectMeta: metav1.ObjectMeta{
			Annotations: map[string]string{
				"alpha.jobset.sigs.k8s.io/exclusive-topology": "cloud.google.com/gke-nodepool",
				"batch.kubernetes.io/job-completion-index":    "0",
				"jobset.sigs.k8s.io/job-index":                "0",
				"jobset.sigs.k8s.io/job-key":                  "random-key",
				"jobset.sigs.k8s.io/jobset-name":              "jobset-test" + b.jobsetNameSuffix,
				"jobset.sigs.k8s.io/replicatedjob-name":       "job-1",
				"jobset.sigs.k8s.io/replicatedjob-replicas":   "1",
				"jobset.sigs.k8s.io/restart-attempt":          "0",
			},
			Labels: map[string]string{
				"batch.kubernetes.io/controller-uid":        "8484279a-de52-4ca1-b01e-130fbded30fb",
				"batch.kubernetes.io/job-name":              "jobset-test-job-1-0",
				"controller-uid":                            "8484279a-de52-4ca1-b01e-130fbded30fb",
				"job-name":                                  "jobset-test-job-1-0",
				"jobset.sigs.k8s.io/job-index":              "0",
				"jobset.sigs.k8s.io/job-key":                "random-key",
				"jobset.sigs.k8s.io/jobset-name":            "jobset-test" + b.jobsetNameSuffix,
				"jobset.sigs.k8s.io/replicatedjob-name":     "job-1",
				"jobset.sigs.k8s.io/replicatedjob-replicas": "1",
				"jobset.sigs.k8s.io/restart-attempt":        "0",
			},
			Finalizers: []string{"batch.kubernetes.io/job-tracking"},
			Name:       "job-test-6gfwq",
			Namespace:  "default",
			OwnerReferences: []metav1.OwnerReference{
				{
					APIVersion:         "batch/v1",
					Kind:               "Job",
					UID:                "8484279a-de52-4ca1-b01e-130fbded30fb",
					Name:               "jobset-test-job-1-0",
					Controller:         &trueVar,
					BlockOwnerDeletion: &trueVar,
				},
			},
			GenerateName:    "jobset-test-job-1-0-0-",
			ResourceVersion: "70731715",
			UID:             "f6a99195-268e-4b68-91de-22e75f9100bc",
		},
		Spec: corev1.PodSpec{
			NodeSelector: b.selector,
			Containers: []corev1.Container{
				{
					Resources: corev1.ResourceRequirements{
						Requests: corev1.ResourceList{
							"google.com/tpu": resource.MustParse(b.tpuResource),
						},
						Limits: corev1.ResourceList{
							"google.com/tpu": resource.MustParse(b.tpuResource),
						},
					},
				},
			},
		},
	}

	for k, v := range b.additionalAnnotations {
		pod.Annotations[k] = v
	}
	for k, v := range b.additionalLabels {
		pod.Labels[k] = v
	}
	for k, v := range b.additionalSelector {
		pod.Spec.NodeSelector[k] = v
	}

	return pod
}

func Test_nodePoolSelectiveHash(t *testing.T) {
	cases := []struct {
		name        string
		A           *container.NodePool
		B           *container.NodePool
		expSameHash bool
	}{
		{
			name:        "two empty",
			A:           &container.NodePool{Config: &container.NodeConfig{}},
			B:           &container.NodePool{Config: &container.NodeConfig{}},
			expSameHash: true,
		},
		{
			name: "different machine type",
			A: &container.NodePool{
				Config: &container.NodeConfig{
					MachineType: "ct5p-hightpu-4t",
				},
			},
			B: &container.NodePool{
				Config: &container.NodeConfig{
					MachineType: "ct5p-hightpu-8t",
				},
			},
			expSameHash: false,
		},
		{
			name: "different labels",
			A: &container.NodePool{
				Config: &container.NodeConfig{
					MachineType: "ct5p-hightpu-4t",
					Labels: map[string]string{
						"a": "b",
					},
				},
			},
			B: &container.NodePool{
				Config: &container.NodeConfig{
					MachineType: "ct5p-hightpu-4t",
					Labels: map[string]string{
						"a": "c",
					},
				},
			},
			expSameHash: false,
		},
		{
			name: "non hashed upgrade settings",
			A: &container.NodePool{
				Config: &container.NodeConfig{
					MachineType: "ct5p-hightpu-4t",
					Labels: map[string]string{
						"a": "b",
						"c": "d",
					},
				},
				UpgradeSettings: &container.UpgradeSettings{
					MaxSurge: 1,
				},
			},
			B: &container.NodePool{
				Config: &container.NodeConfig{
					MachineType: "ct5p-hightpu-4t",
					Labels: map[string]string{
						"a": "b",
						"c": "d",
					},
				},
				UpgradeSettings: &container.UpgradeSettings{
					MaxSurge: 2,
				},
			},
			expSameHash: true,
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			hashA, err := nodePoolSelectiveHash(c.A)
			if err != nil {
				t.Fatalf("Unexpected error: %v", err)
			}
			hashB, err := nodePoolSelectiveHash(c.B)
			if err != nil {
				t.Fatalf("Unexpected error: %v", err)
			}
			if c.expSameHash {
				if hashA != hashB {
					t.Errorf("Expected same hash, got %s and %s", hashA, hashB)
				}
			} else {
				if hashA == hashB {
					t.Errorf("Expected different hash, got %s", hashA)
				}
			}
		})
	}
}
