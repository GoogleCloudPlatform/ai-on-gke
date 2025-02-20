package cloud

import (
	"context"
	"fmt"
	"net/http"

	containerv1beta1 "google.golang.org/api/container/v1beta1"
	"google.golang.org/api/googleapi"
)

type NodePoolService interface {
	Get(ctx context.Context, name string) (*containerv1beta1.NodePool, error)
	List(ctx context.Context) (*containerv1beta1.ListNodePoolsResponse, error)
	Create(ctx context.Context, req *containerv1beta1.CreateNodePoolRequest, callbacks OpCallbacks) error
	Delete(ctx context.Context, name string, callbacks OpCallbacks) error
}

type OpCallbacks struct {
	NotFound   func()
	ReqFailure func(err error)
	OpFailure  func(err error)
	Success    func()
}

var _ NodePoolService = &GKENodePoolService{}

type GKENodePoolService struct {
	ClusterContext GKEContext
	Service        *containerv1beta1.Service
}

func (g *GKENodePoolService) Get(ctx context.Context, name string) (*containerv1beta1.NodePool, error) {
	return g.Service.Projects.Locations.Clusters.NodePools.Get(g.ClusterContext.NodePoolName(name)).Context(ctx).Do()
}

func (g *GKENodePoolService) List(ctx context.Context) (*containerv1beta1.ListNodePoolsResponse, error) {
	return g.Service.Projects.Locations.Clusters.NodePools.List(g.ClusterContext.ClusterName()).Context(ctx).Do()
}

func (g *GKENodePoolService) Create(ctx context.Context, req *containerv1beta1.CreateNodePoolRequest, callbacks OpCallbacks) error {
	call := g.Service.Projects.Locations.Clusters.NodePools.Create(g.ClusterContext.ClusterName(), req)
	op, err := call.Do()
	if err != nil {
		if callbacks.ReqFailure != nil {
			callbacks.ReqFailure(err)
		}
		return fmt.Errorf("do: %w", err)
	}

	if err := waitForGkeOp(g.Service, g.ClusterContext, op); err != nil {
		if callbacks.OpFailure != nil {
			callbacks.OpFailure(err)
		}
		return fmt.Errorf("waiting for operation: %w", err)
	}

	if callbacks.Success != nil {
		callbacks.Success()
	}
	return nil
}

func (g *GKENodePoolService) Delete(ctx context.Context, name string, callbacks OpCallbacks) error {
	op, err := g.Service.Projects.Locations.Clusters.Delete(g.ClusterContext.NodePoolName(name)).Context(ctx).Do()
	if err != nil {
		if gerr, ok := err.(*googleapi.Error); ok && gerr.Code == http.StatusNotFound {
			if callbacks.NotFound != nil {
				callbacks.NotFound()
			}
			return nil
		}
		if callbacks.ReqFailure != nil {
			callbacks.ReqFailure(err)
		}
		return fmt.Errorf("deleting node pool %q: %w", name, err)
	}

	if err := waitForGkeOp(g.Service, g.ClusterContext, op); err != nil {
		if callbacks.OpFailure != nil {
			callbacks.OpFailure(err)
		}
		return err
	}

	if callbacks.Success != nil {
		callbacks.Success()
	}
	return nil
}
