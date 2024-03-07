package cloud

const (
	keyPrefix = "google.com/"

	LabelNodepoolManager             = keyPrefix + "nodepool-manager"
	LabelNodepoolManagerTPUPodinator = "tpu-provisioner"

	LabelParentKind      = keyPrefix + "tpu-provisioner-parent-kind"
	LabelParentName      = keyPrefix + "tpu-provisioner-parent-name"
	LabelParentNamespace = keyPrefix + "tpu-provisioner-parent-namespace"

	LabelPodName      = keyPrefix + "tpu-provisioner-pod-name"
	LabelPodNamespace = keyPrefix + "tpu-provisioner-pod-namespace"

	EventNodePoolCreationStarted   = "NodePoolCreationStarted"
	EventNodePoolCreationSucceeded = "NodePoolCreationSucceeded"
	EventNodePoolCreationFailed    = "NodePoolCreationFailed"

	EventNodePoolDeletionStarted   = "NodePoolDeletionStarted"
	EventNodePoolDeletionSucceeded = "NodePoolDeletionSucceeded"
	EventNodePoolDeletionFailed    = "NodePoolDeletionFailed"

	EventNodePoolNotFound = "NodePoolNotFound"
)
