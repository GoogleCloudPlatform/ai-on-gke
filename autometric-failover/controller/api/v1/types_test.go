package v1

import (
	"testing"
)

func TestDefaulting_ActionRequest_DefaultAndValidate(t *testing.T) {
	tests := []struct {
		name     string
		request  *ActionRequest
		expected *ActionRequest
	}{
		{
			name: "sets default namespace",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			expected: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Namespace:  "default",
				Reason:     "test reason",
			},
		},
		{
			name: "generates ID if not provided",
			request: &ActionRequest{
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			expected: nil, // ID will be generated, can't predict exact value
		},
		{
			name: "preserves provided values",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Namespace:  "custom-ns",
				Reason:     "test reason",
			},
			expected: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Namespace:  "custom-ns",
				Reason:     "test reason",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.request.DefaultAndValidate()
			if err != nil {
				t.Errorf("DefaultAndValidate() error = %v, expected no error", err)
				return
			}

			if tt.expected == nil {
				// For cases where we can't predict exact values (like generated IDs)
				if tt.request.ID == "" {
					t.Error("ID was not generated")
				}
			} else {
				if tt.request.ID != tt.expected.ID {
					t.Errorf("ID = %v, expected %v", tt.request.ID, tt.expected.ID)
				}
				if tt.request.Requestor != tt.expected.Requestor {
					t.Errorf("Requestor = %v, expected %v", tt.request.Requestor, tt.expected.Requestor)
				}
				if tt.request.Type != tt.expected.Type {
					t.Errorf("Type = %v, expected %v", tt.request.Type, tt.expected.Type)
				}
				if tt.request.NodePool != tt.expected.NodePool {
					t.Errorf("NodePool = %v, expected %v", tt.request.NodePool, tt.expected.NodePool)
				}
				if tt.request.JobSetName != tt.expected.JobSetName {
					t.Errorf("JobSetName = %v, expected %v", tt.request.JobSetName, tt.expected.JobSetName)
				}
				if tt.request.Namespace != tt.expected.Namespace {
					t.Errorf("JobSetNamespace = %v, expected %v", tt.request.Namespace, tt.expected.Namespace)
				}
				if tt.request.Reason != tt.expected.Reason {
					t.Errorf("Reason = %v, expected %v", tt.request.Reason, tt.expected.Reason)
				}
			}
		})
	}
}

func TestValidating_ActionRequest_DefaultAndValidate(t *testing.T) {
	tests := []struct {
		name    string
		request *ActionRequest
		wantErr bool
		errMsg  string
	}{
		{
			name: "valid cordon nodepool request",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			wantErr: false,
		},
		{
			name: "valid cordon and restart request",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepoolAndRestartJobSet,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Namespace:  "test-namespace",
				Reason:     "test reason",
			},
			wantErr: false,
		},
		{
			name: "missing id - should generate one",
			request: &ActionRequest{
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			wantErr: false,
		},
		{
			name: "missing namespace - should default to 'default'",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			wantErr: false,
		},
		{
			name: "missing requestor",
			request: &ActionRequest{
				ID:         "test-id",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			wantErr: true,
			errMsg:  "requestor is required",
		},
		{
			name: "missing node pool for cordon nodepool",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			wantErr: true,
			errMsg:  "node_pool or node_name is required for cordon_nodepool action",
		},
		{
			name: "missing node pool for cordon and restart",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepoolAndRestartJobSet,
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			wantErr: false,
		},
		{
			name: "missing jobset name for cordon nodepool",
			request: &ActionRequest{
				ID:        "test-id",
				Requestor: "test-user",
				Type:      ActionTypeCordonNodepool,
				NodePool:  "test-pool",
				Reason:    "test reason",
			},
			wantErr: false,
		},
		{
			name: "missing jobset name for cordon and restart",
			request: &ActionRequest{
				ID:        "test-id",
				Requestor: "test-user",
				Type:      ActionTypeCordonNodepoolAndRestartJobSet,
				NodePool:  "test-pool",
				Reason:    "test reason",
			},
			wantErr: true,
			errMsg:  "jobset_name is required for cordon_nodepool_and_restart_jobset action",
		},
		{
			name: "valid cordon and repair request",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonAndRepairNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			wantErr: false,
		},
		{
			name: "missing node pool for cordon and repair",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonAndRepairNodepool,
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			wantErr: true,
			errMsg:  "node_pool or node_name is required for cordon_and_repair_nodepool action",
		},
		{
			name: "missing jobset name for cordon and repair",
			request: &ActionRequest{
				ID:        "test-id",
				Requestor: "test-user",
				Type:      ActionTypeCordonAndRepairNodepool,
				NodePool:  "test-pool",
				Reason:    "test reason",
			},
			wantErr: false,
		},
		{
			name: "unknown action type",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       "invalid-action",
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
				Reason:     "test reason",
			},
			wantErr: true,
			errMsg:  "unknown action type: invalid-action",
		},
		{
			name: "missing reason",
			request: &ActionRequest{
				ID:         "test-id",
				Requestor:  "test-user",
				Type:       ActionTypeCordonNodepool,
				NodePool:   "test-pool",
				JobSetName: "test-jobset",
			},
			wantErr: true,
			errMsg:  "reason is required",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.request.DefaultAndValidate()
			if (err != nil) != tt.wantErr {
				t.Errorf("ActionRequest.DefaultAndValidate() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if tt.wantErr && err.Error() != tt.errMsg {
				t.Errorf("ActionRequest.DefaultAndValidate() error message = %v, want %v", err.Error(), tt.errMsg)
			}
			if !tt.wantErr {
				// Check default values were set
				if tt.request.ID == "" {
					t.Error("ID was not generated for request with missing ID")
				}
				if tt.request.Namespace == "" {
					t.Error("JobSetNamespace was not defaulted to 'default'")
				}
			}
		})
	}
}
