package controller

import (
	"context"
	"fmt"
	"time"

	"github.com/GoogleCloudPlatform/ai-on-gke/tpu-provisioner/internal/cloud"
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
	ctrllog "sigs.k8s.io/controller-runtime/pkg/log"
)

type NodePoolGarbageCollector struct {
	Interval time.Duration
	client.Client
	Provider cloud.Provider
}

func (g *NodePoolGarbageCollector) Run(ctx context.Context) {
	log := ctrllog.Log.WithName("nodepool-garbage-collector")

	t := time.NewTicker(g.Interval)

	for {
		select {
		case <-ctx.Done():
			t.Stop()
			return
		case <-t.C:
		}

		log.Info("starting node pool garbage collection loop")

		nodepools, err := g.Provider.ListNodePools()
		if err != nil {
			log.Error(err, "failed to list errored node pools")
			continue
		}

		for _, np := range nodepools {
			log := log.WithValues(
				"nodepool", np.Name,
				"createdForPodName", np.CreatedForPod.Name,
				"createdForPodNamespace", np.CreatedForPod.Namespace,
			)

			if !np.Error {
				continue
			}

			if np.CreatedForPod.Name == "" || np.CreatedForPod.Namespace == "" {
				log.Info("skipping garbage collection of node pool, no pod reference")
				continue
			}

			// Check if the Pod that triggered the Node Pool creation still exists.
			err := g.Get(ctx, np.CreatedForPod, &v1.Pod{})
			if err == nil {
				log.Info("skipping garbage collection of node pool, pod still exists",
					"podName", np.CreatedForPod.Name,
					"podNamespace", np.CreatedForPod.Namespace,
				)
				continue
			}
			if client.IgnoreNotFound(err) != nil {
				log.Error(err, "failed to get pod node pool was created for")
				continue
			}
			// Pod not found if this point is reached.

			// Ignore node pools that have Nodes registered for them (these will be handled by the deletion controller).
			var nodes v1.NodeList
			if err := g.List(ctx, &nodes, client.MatchingLabels{g.Provider.NodePoolLabelKey(): np.Name}); err != nil {
				log.Error(err, "failed to list nodes for node pool")
				continue
			}
			if len(nodes.Items) > 0 {
				log.Info("skipping garbage collection of node pool, nodes exist")
				continue
			}

			log.Info("garbage collecting node pool in error state")
			// TODO: Lookup namespace from env with downward API.
			whyDelete := fmt.Sprintf("the node pool has no corresponding Nodes, the Pod (%s/%s) that triggered its creation no longer exists, and node pool is in an error state: %s",
				np.CreatedForPod.Namespace, np.CreatedForPod.Name, np.ErrorMsg)
			if err := g.Provider.DeleteNodePool(np.Name, &v1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "tpu-provisioner-system"}}, whyDelete); err != nil {
				log.Error(err, "failed to garbage collect node pool")
				continue
			}
		}
	}
}
