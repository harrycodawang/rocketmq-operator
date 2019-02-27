/*
Copyright The Kubernetes Authors.

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

// Code generated by lister-gen. DO NOT EDIT.

package v1alpha1

import (
	v1alpha1 "github.com/harrycodawang/rocketmq-operator/pkg/apis/rocketmq/v1alpha1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/tools/cache"
)

// BrokerClusterLister helps list BrokerClusters.
type BrokerClusterLister interface {
	// List lists all BrokerClusters in the indexer.
	List(selector labels.Selector) (ret []*v1alpha1.BrokerCluster, err error)
	// BrokerClusters returns an object that can list and get BrokerClusters.
	BrokerClusters(namespace string) BrokerClusterNamespaceLister
	BrokerClusterListerExpansion
}

// brokerClusterLister implements the BrokerClusterLister interface.
type brokerClusterLister struct {
	indexer cache.Indexer
}

// NewBrokerClusterLister returns a new BrokerClusterLister.
func NewBrokerClusterLister(indexer cache.Indexer) BrokerClusterLister {
	return &brokerClusterLister{indexer: indexer}
}

// List lists all BrokerClusters in the indexer.
func (s *brokerClusterLister) List(selector labels.Selector) (ret []*v1alpha1.BrokerCluster, err error) {
	err = cache.ListAll(s.indexer, selector, func(m interface{}) {
		ret = append(ret, m.(*v1alpha1.BrokerCluster))
	})
	return ret, err
}

// BrokerClusters returns an object that can list and get BrokerClusters.
func (s *brokerClusterLister) BrokerClusters(namespace string) BrokerClusterNamespaceLister {
	return brokerClusterNamespaceLister{indexer: s.indexer, namespace: namespace}
}

// BrokerClusterNamespaceLister helps list and get BrokerClusters.
type BrokerClusterNamespaceLister interface {
	// List lists all BrokerClusters in the indexer for a given namespace.
	List(selector labels.Selector) (ret []*v1alpha1.BrokerCluster, err error)
	// Get retrieves the BrokerCluster from the indexer for a given namespace and name.
	Get(name string) (*v1alpha1.BrokerCluster, error)
	BrokerClusterNamespaceListerExpansion
}

// brokerClusterNamespaceLister implements the BrokerClusterNamespaceLister
// interface.
type brokerClusterNamespaceLister struct {
	indexer   cache.Indexer
	namespace string
}

// List lists all BrokerClusters in the indexer for a given namespace.
func (s brokerClusterNamespaceLister) List(selector labels.Selector) (ret []*v1alpha1.BrokerCluster, err error) {
	err = cache.ListAllByNamespace(s.indexer, s.namespace, selector, func(m interface{}) {
		ret = append(ret, m.(*v1alpha1.BrokerCluster))
	})
	return ret, err
}

// Get retrieves the BrokerCluster from the indexer for a given namespace and name.
func (s brokerClusterNamespaceLister) Get(name string) (*v1alpha1.BrokerCluster, error) {
	obj, exists, err := s.indexer.GetByKey(s.namespace + "/" + name)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, errors.NewNotFound(v1alpha1.Resource("brokercluster"), name)
	}
	return obj.(*v1alpha1.BrokerCluster), nil
}
