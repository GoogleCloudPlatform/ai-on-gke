package cloud

import "fmt"

type GKEContext struct {
	ProjectID          string
	ClusterLocation    string
	Cluster            string
	NodeZone           string
	NodeServiceAccount string
	NodeSecondaryDisk  string
	NodeTags           []string
	NodeSecureBoot     bool
	ForceOnDemand      bool
}

func (c GKEContext) ClusterName() string {
	return fmt.Sprintf("projects/%v/locations/%v/clusters/%v",
		c.ProjectID,
		c.ClusterLocation,
		c.Cluster,
	)
}

func (c GKEContext) NodePoolName(name string) string {
	return fmt.Sprintf("projects/%v/locations/%v/clusters/%v/nodePools/%v",
		c.ProjectID,
		c.ClusterLocation,
		c.Cluster,
		name,
	)
}

func (c GKEContext) OpName(op string) string {
	return fmt.Sprintf("projects/%v/locations/%v/operations/%v",
		c.ProjectID,
		c.ClusterLocation,
		op,
	)
}
