package cert

import (
	"fmt"

	cert "github.com/open-policy-agent/cert-controller/pkg/rotator"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
)

const (
	serviceName             = "tpu-provisioner-webhook-service"
	secretName              = "tpu-provisioner-webhook-server-cert"
	secretNamespace         = "tpu-provisioner-system"
	certDir                 = "/tmp/k8s-webhook-server/serving-certs"
	validateWebhookConfName = "tpu-provisioner-validating-webhook-configuration"
	mutatingWebhookConfName = "tpu-provisioner-mutating-webhook-configuration"
	caName                  = "tpu-provisioner-ca"
	caOrg                   = "tpu-provisioner"
)

// dnsName is the format of <service name>.<namespace>.svc
var dnsName = fmt.Sprintf("%s.%s.svc", serviceName, secretNamespace)

//+kubebuilder:rbac:groups="",resources=secrets,verbs=get;list;watch;update
//+kubebuilder:rbac:groups="admissionregistration.k8s.io",resources=mutatingwebhookconfigurations,verbs=get;list;watch;update
//+kubebuilder:rbac:groups="admissionregistration.k8s.io",resources=validatingwebhookconfigurations,verbs=get;list;watch;update

// CertsManager creates certs for webhooks.
func CertsManager(mgr ctrl.Manager, setupFinish chan struct{}) error {
	return cert.AddRotator(mgr, &cert.CertRotator{
		SecretKey: types.NamespacedName{
			Namespace: secretNamespace,
			Name:      secretName,
		},
		CertDir:        certDir,
		CAName:         caName,
		CAOrganization: caOrg,
		DNSName:        dnsName,
		IsReady:        setupFinish,
		Webhooks: []cert.WebhookInfo{
			{
				Type: cert.Mutating,
				Name: mutatingWebhookConfName,
			},
		},
	})
}
