package main

import (
	"context"
	"flag"
	"net/http"
	"os"
	"strconv"
	"time"

	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/labels"

	// Import all Kubernetes client auth plugins (e.g. Azure, GCP, OIDC, etc.)
	// to ensure that exec-entrypoint and run can make use of them.
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/actions"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/controller"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/gcp"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/historydb"
	"github.com/GoogleCloudPlatform/ai-on-gke/autometric-failover/controller/internal/server"
	_ "k8s.io/client-go/plugin/pkg/client/auth"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/cache"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/healthz"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	"sigs.k8s.io/controller-runtime/pkg/metrics/filters"
	metricsserver "sigs.k8s.io/controller-runtime/pkg/metrics/server"
	jobsetv1a "sigs.k8s.io/jobset/api/jobset/v1alpha2"
	// +kubebuilder:scaffold:imports
)

var (
	scheme   = runtime.NewScheme()
	setupLog = ctrl.Log.WithName("setup")

	// Server configuration
	serverAddr            string
	serverShutdownTimeout = 5 * time.Second
)

func init() {
	utilruntime.Must(clientgoscheme.AddToScheme(scheme))

	utilruntime.Must(jobsetv1a.AddToScheme(scheme))
	// +kubebuilder:scaffold:scheme
}

// nolint:gocyclo
func main() {
	var (
		metricsAddr          string
		enableLeaderElection bool
		probeAddr            string
		secureMetrics        bool
		noOpGCPClient        bool
		noOpActionTaker      bool

		enableDB bool
		dbHost   string
		dbPort   string
		dbUser   string
		dbName   string
		dbPass   = os.Getenv("DB_PASSWORD")
	)

	// Server configuration flags
	flag.StringVar(&serverAddr, "server-addr", ":8080", "The address the HTTP server binds to.")
	flag.StringVar(&metricsAddr, "metrics-bind-address", "0", "The address the metrics endpoint binds to. "+
		"Use :8082 to enable, or leave as 0 to disable the metrics service.")
	flag.StringVar(&probeAddr, "health-probe-bind-address", ":8081", "The address the probe endpoint binds to.")
	flag.BoolVar(&enableLeaderElection, "leader-elect", false,
		"Enable leader election for controller manager. "+
			"Enabling this will ensure there is only one active controller manager.")
	flag.BoolVar(&secureMetrics, "metrics-secure", true,
		"If set, the metrics endpoint is served securely via HTTPS. Use --metrics-secure=false to use HTTP instead.")
	flag.BoolVar(&noOpGCPClient, "no-op-gcp-client", false, "If set, the GCP client will be a no-op.")
	flag.BoolVar(&noOpActionTaker, "no-op-action-taker", false, "If set, the action taker will be a no-op.")

	// HistoryDB configuration flags
	// historyDBHost, historyDBPort, historyDBUser, historyDBPassword, historyDBName
	flag.BoolVar(&enableDB, "enable-db", false, "If set, the history DB will be enabled.")
	flag.StringVar(&dbHost, "db-host", "localhost", "The host of the history DB.")
	flag.StringVar(&dbPort, "db-port", "5432", "The port of the history DB.")
	flag.StringVar(&dbUser, "db-user", "postgres", "The user of the history DB.")
	flag.StringVar(&dbName, "db-name", "postgres", "The name of the history DB.")

	opts := zap.Options{
		Development: true,
	}
	opts.BindFlags(flag.CommandLine)
	flag.Parse()

	ctrl.SetLogger(zap.New(zap.UseFlagOptions(&opts)))

	// Metrics endpoint is enabled in 'config/default/kustomization.yaml'. The Metrics options configure the server.
	// More info:
	// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.20.2/pkg/metrics/server
	// - https://book.kubebuilder.io/reference/metrics.html
	metricsServerOptions := metricsserver.Options{
		BindAddress:   metricsAddr,
		SecureServing: secureMetrics,
	}

	if secureMetrics {
		// FilterProvider is used to protect the metrics endpoint with authn/authz.
		// These configurations ensure that only authorized users and service accounts
		// can access the metrics endpoint. The RBAC are configured in 'config/rbac/kustomization.yaml'. More info:
		// https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.20.2/pkg/metrics/filters#WithAuthenticationAndAuthorization
		metricsServerOptions.FilterProvider = filters.WithAuthenticationAndAuthorization
	}

	// Only watch JobSet leader pods so that Jobs can be bound to the node
	// pools that they are scheduled on.
	//
	// jobset.sigs.k8s.io/jobset-name (exists)
	// batch.kubernetes.io/job-completion-index: "0"
	//
	jobsetPodSelector, err := labels.Parse("jobset.sigs.k8s.io/jobset-name, batch.kubernetes.io/job-completion-index=0")
	if err != nil {
		setupLog.Error(err, "unable to create jobset pod selector")
		os.Exit(1)
	}
	// Only watch Pods that are already scheduled to a Node.
	scheduledPodSelector, err := fields.ParseSelector("spec.nodeName!=")
	if err != nil {
		setupLog.Error(err, "unable to create scheduled pod selector")
		os.Exit(1)
	}

	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:                 scheme,
		Metrics:                metricsServerOptions,
		HealthProbeBindAddress: probeAddr,
		LeaderElection:         enableLeaderElection,
		LeaderElectionID:       "ecaf1259.my.domain",
		// LeaderElectionReleaseOnCancel defines if the leader should step down voluntarily
		// when the Manager ends. This requires the binary to immediately end when the
		// Manager is stopped, otherwise, this setting is unsafe. Setting this significantly
		// speeds up voluntary leader transitions as the new leader don't have to wait
		// LeaseDuration time first.
		//
		// In the default scaffold provided, the program ends immediately after
		// the manager stops, so would be fine to enable this option. However,
		// if you are doing or is intended to do any operation such as perform cleanups
		// after the manager stops then its usage might be unsafe.
		// LeaderElectionReleaseOnCancel: true,
		Cache: cache.Options{
			ByObject: map[client.Object]cache.ByObject{
				&corev1.Pod{}: {
					Label: jobsetPodSelector,
					Field: scheduledPodSelector,
				},
			},
		},
	})
	if err != nil {
		setupLog.Error(err, "unable to start manager")
		os.Exit(1)
	}

	var historyDB historydb.DBInterface
	if enableDB {
		historyDB, err = historydb.NewDB(dbHost, dbPort, dbUser, dbPass, dbName)
		if err != nil {
			setupLog.Error(err, "unable to create history DB")
			os.Exit(1)
		}
	} else {
		historyDB = &historydb.NoopDB{}
	}

	if err := (&controller.PodReconciler{
		Client:    mgr.GetClient(),
		Scheme:    mgr.GetScheme(),
		HistoryDB: historyDB,
	}).SetupWithManager(mgr); err != nil {
		setupLog.Error(err, "unable to create controller", "controller", "pod")
		os.Exit(1)
	}
	// +kubebuilder:scaffold:builder

	if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
		setupLog.Error(err, "unable to set up health check")
		os.Exit(1)
	}
	if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
		setupLog.Error(err, "unable to set up ready check")
		os.Exit(1)
	}

	// Set up graceful shutdown context
	ctx := ctrl.SetupSignalHandler()

	var gcpClient actions.GCPClient
	if noOpGCPClient {
		setupLog.Info("using no-op GCP client")
		gcpClient = &actions.NoOpGCPClient{}
	} else {
		// Initialize GCP client
		gcpClient, err = gcp.NewClient(ctx)
		if err != nil {
			setupLog.Error(err, "unable to create GCP client")
			os.Exit(1)
		}
	}

	// Initialize the action taker and HTTP server
	var actionTaker actions.ActionTakerInterface
	if noOpActionTaker {
		setupLog.Info("using no-op action taker")
		actionTaker = &actions.NoOpActionTaker{}
	} else {
		actionTaker = actions.NewActionTaker(ctx,
			mgr.GetClient(),
			gcpClient,
			mgr.GetEventRecorderFor("autometric-failover-controller"),
			actions.NewInMemoryRateLimiter(nil),
		)
	}

	httpServer := &http.Server{
		Addr:    serverAddr,
		Handler: server.New(actionTaker),
	}

	// Start HTTP server in a separate goroutine
	go func() {
		setupLog.Info("starting HTTP server", "addr", serverAddr)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			setupLog.Error(err, "problem running HTTP server")
			os.Exit(1)
		}
	}()

	// Start the manager
	setupLog.Info("starting manager")
	go func() {
		if err := mgr.Start(ctx); err != nil {
			setupLog.Error(err, "problem running manager")
			os.Exit(1)
		}
	}()

	// Wait for shutdown signal
	<-ctx.Done()

	// Graceful shutdown
	shutdownCtx, cancel := context.WithTimeout(context.Background(), serverShutdownTimeout)
	defer cancel()

	setupLog.Info("shutting down HTTP server")
	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		setupLog.Error(err, "problem shutting down HTTP server")
	}

	// Wait for manager to shut down
	setupLog.Info("waiting for manager to shut down")
}

func unquote(s string) string {
	u, err := strconv.Unquote(s)
	if err != nil {
		return s
	}
	return u
}
