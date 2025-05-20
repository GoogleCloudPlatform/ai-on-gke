/*
Copyright 2025.

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

package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// SliceSpec defines the desired state of Slice
type SliceSpec struct {
	// TpuType specifies the type of TPU used in this slice.
	// +kubebuilder:validation:Immutable
	TpuType string `json:"tpuType"`

	// Topology represents the network topology of the slice.
	// +kubebuilder:validation:Immutable
	TpuTopology string `json:"tpuTopology"`

	// If set, then user is telling the controller which nodes to use to form slice
	Nodes []string `json:"nodes"`
}

// SliceStatus defines the observed state of Slice
type SliceStatus struct {
	// State represents the current state of the slice.
	State SliceState `json:"state"`

	// LastTransitionTime is the last time the state transitioned.
	LastTransitionTime metav1.Time `json:"lastTransitionTime,omitempty"`

	// If the SuperSlice is running in a DEGRADED state
	IsDegraded bool `json:"isDegraded,omitempty"`

	// Populated to match the physical topology of block the slice is running on
	BlockID string `json:"blockId,omitempty"`

	// Populated to list of physical topology of sub-block the slice is running on
	SubBlockIDs []string `json:"subBlockIds,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="TpuType",type=string,JSONPath=`.spec.tpuType`
// +kubebuilder:printcolumn:name="Topology",type=string,JSONPath=`.spec.tpuTopology`
// +kubebuilder:printcolumn:name="Status",type=string,JSONPath=`.status.state`
// +kubebuilder:printcolumn:name="Age",type="date",JSONPath=".metadata.creationTimestamp"
// Slice is the Schema for the slices API
type Slice struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   SliceSpec   `json:"spec,omitempty"`
	Status SliceStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// SliceList contains a list of Slice.
type SliceList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Slice `json:"items"`
}

// +kubebuilder:validation:Enum=FORMING;RUNNING;ERROR;DEFORMED;
type SliceState string

const (
	// SliceStateForming means the slice is currently being provisioned or configured.
	SliceStateForming SliceState = "FORMING"
	// SliceStateRunning means the slice is provisioned and operational.
	SliceStateRunning SliceState = "RUNNING"
	// SliceStateError means the slice encountered an error during its lifecycle.
	SliceStateError SliceState = "ERROR"
	// SliceStateDeformed means the slice is being torn down or has been released.
	SliceStateDeformed SliceState = "DEFORMED"
)

func init() {
	SchemeBuilder.Register(&Slice{}, &SliceList{})
}
