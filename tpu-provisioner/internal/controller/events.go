package controller

// +kubebuilder:rbac:groups="",resources=events,verbs=create;patch

const (
	EventFailedEnsuringNodePool  = "FailedEnsuringNodePool"
	EventFailedDeletingNodePool  = "FailedDeletingNodePool"
	EventEnsuringNodePool        = "EnsuringNodePool"
	EventNodePoolEnsured         = "NodePoolEnsured"
	EventDeletingNodePool        = "DeletingNodePool"
	EventNodePoolDeleted         = "NodePoolDeleted"
	DeletingNodePoolEventMessage = "Deleting Node Pool."
	DeletedNodePoolEventMessage  = "Deleted Node Pool."
)
