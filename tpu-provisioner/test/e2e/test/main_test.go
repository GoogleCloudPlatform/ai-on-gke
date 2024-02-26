/*
Copyright 2024 The Kubernetes Authors.
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

package e2e_test

import (
	"context"
	"log"
	"os"
	"testing"

	"k8s.io/client-go/kubernetes/scheme"
	runtimeclient "sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	jobset "sigs.k8s.io/jobset/api/jobset/v1alpha2"
)

var (
	ctx    = context.Background()
	client runtimeclient.Client
)

func TestMain(m *testing.M) {
	if err := jobset.AddToScheme(scheme.Scheme); err != nil {
		log.Fatalf("failed to add to scheme: %v", err)
		os.Exit(1)
	}

	var err error
	client, err = runtimeclient.New(config.GetConfigOrDie(), runtimeclient.Options{
		Scheme: scheme.Scheme,
	})
	if err != nil {
		log.Fatalf("failed to create client: %v", err)
	}

	// Create a kubernetes client from the kubeconfig file.
	if status := m.Run(); status != 0 {
		os.Exit(status)
	}
}
