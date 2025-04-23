package utils_test

import (
	"testing"

	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/utils"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func TestGetExpectedTPUNodePoolSize(t *testing.T) {
	t.Parallel()

	cases := map[string]struct {
		node            *corev1.Node
		want            int32
		wantErrContains string
	}{
		"empty": {
			node:            &corev1.Node{},
			wantErrContains: "no annotations",
		},
		"v5e 16x16 4": {
			node: &corev1.Node{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"cloud.google.com/gke-tpu-topology":      "16x16",
						"cloud.google.com/gke-accelerator-count": "4",
					},
				},
			},
			want: 64,
		},
		"v5e 2x4 8": {
			node: &corev1.Node{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"cloud.google.com/gke-tpu-topology":      "2x4",
						"cloud.google.com/gke-accelerator-count": "8",
					},
				},
			},
			want: 1,
		},
		"v5e 2x4 4": {
			node: &corev1.Node{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"cloud.google.com/gke-tpu-topology":      "2x4",
						"cloud.google.com/gke-accelerator-count": "4",
					},
				},
			},
			want: 2,
		},
		"v5p 8x8x8 4": {
			node: &corev1.Node{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"cloud.google.com/gke-tpu-topology":      "8x8x8",
						"cloud.google.com/gke-accelerator-count": "4",
					},
				},
			},
			want: 128,
		},
	}

	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			got, err := utils.GetExpectedTPUNodePoolSize(c.node)
			if c.wantErrContains != "" {
				require.Error(t, err)
				require.ErrorContains(t, err, c.wantErrContains)
			}
			require.Equal(t, c.want, got)
		})
	}

}

func TestGetTpuTopologyToChipCount(t *testing.T) {
	t.Parallel()

	cases := map[string]struct {
		topo            string
		want            int
		wantErrContains string
	}{
		"valid 2x2": {
			topo: "2x2",
			want: 4,
		},
		"valid 2x4": {
			topo: "2x4",
			want: 8,
		},
		"valid 4x2": {
			topo: "4x2",
			want: 8,
		},
		"valid 8x8x8": {
			topo: "8x8x8",
			want: 512,
		},
		"invalid empty": {
			topo:            "",
			wantErrContains: "invalid topology",
		},
		"invalid single": {
			topo:            "2",
			wantErrContains: "invalid topology",
		},
		"invalid 2x": {
			topo:            "2x",
			wantErrContains: "invalid topology",
		},
		"invalid x2": {
			topo:            "x2",
			wantErrContains: "invalid topology",
		},
	}

	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			got, err := utils.TPUTopologyToChipCount(c.topo)
			if c.wantErrContains != "" {
				require.Error(t, err)
				require.ErrorContains(t, err, c.wantErrContains)
				return
			}
			require.NoError(t, err)
			require.Equal(t, c.want, got)
		})
	}
}

func TestParseProviderID(t *testing.T) {
	t.Parallel()

	cases := map[string]struct {
		providerID      string
		wantProject     string
		wantZone        string
		wantInstance    string
		wantErrContains string
	}{
		"valid provider ID": {
			providerID:   "gce://my-project-id/us-east5-a/my-instance-name",
			wantProject:  "my-project-id",
			wantZone:     "us-east5-a",
			wantInstance: "my-instance-name",
		},
		"valid provider ID with hyphens and numbers": {
			providerID:   "gce://project-123/us-central1-c/gke-cluster-1-default-pool-12345678-abcd",
			wantProject:  "project-123",
			wantZone:     "us-central1-c",
			wantInstance: "gke-cluster-1-default-pool-12345678-abcd",
		},
		"invalid scheme": {
			providerID:      "aws://my-project-id/us-east5-a/my-instance-name",
			wantErrContains: "invalid GCE provider ID format",
		},
		"missing scheme": {
			providerID:      "my-project-id/us-east5-a/my-instance-name",
			wantErrContains: "invalid GCE provider ID format",
		},
		"too few parts": {
			providerID:      "gce://my-project-id/us-east5-a",
			wantErrContains: "invalid GCE provider ID format",
		},
		"too many parts": {
			providerID:      "gce://my-project-id/us-east5-a/my-instance-name/extra",
			wantErrContains: "invalid GCE provider ID format",
		},
		"empty string": {
			providerID:      "",
			wantErrContains: "invalid GCE provider ID format",
		},
	}

	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			t.Parallel()
			gotProject, gotZone, gotInstance, err := utils.ParseProviderID(c.providerID)
			if c.wantErrContains != "" {
				require.Error(t, err)
				require.ErrorContains(t, err, c.wantErrContains)
				return
			}
			require.NoError(t, err)
			require.Equal(t, c.wantProject, gotProject)
			require.Equal(t, c.wantZone, gotZone)
			require.Equal(t, c.wantInstance, gotInstance)
		})
	}
}
