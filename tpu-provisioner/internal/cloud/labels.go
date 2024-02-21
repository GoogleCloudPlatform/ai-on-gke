package cloud

const (
	keyPrefix = "google.com/"

	LabelNodepoolManager             = keyPrefix + "nodepool-manager"
	LabelNodepoolManagerTPUPodinator = "tpu-provisioner"

	LabelParentKind      = keyPrefix + "tpu-provisioner-parent-kind"
	LabelParentName      = keyPrefix + "tpu-provisioner-parent-name"
	LabelParentNamespace = keyPrefix + "tpu-provisioner-parent-namespace"
)
