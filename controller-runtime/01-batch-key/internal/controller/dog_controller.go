package controller

import (
	"context"
	"fmt"
	"strings"

	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	pseudoclusterscopekeyexamplecomv1alpha1 "github.com/suinplayground/kubernetes-playground/controller-runtime/01-pseudo-cluster-scope-key/api/v1alpha1"
)

// Field indexer constant for spec.foo
const idxFoo = ".spec.foo"

// Prefix for batch keys
const prefixFoo = "spec.foo:"

// DogReconciler reconciles a Dog object
type DogReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=pseudo-cluster-scope-key.example.com,resources=dogs,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=pseudo-cluster-scope-key.example.com,resources=dogs/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=pseudo-cluster-scope-key.example.com,resources=dogs/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// This implementation uses the "BatchKey" pattern where
// the reconcile request key is the prefixed foo value, and we process all Dogs
// with that foo value in a single reconciliation loop.
func (r *DogReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	// Extract the actual foo value by removing the prefix
	fooValue := strings.TrimPrefix(req.Name, prefixFoo)
	l := log.FromContext(ctx).WithName(fooValue)

	// req.Name == "spec.foo:<actual_foo_value>" (batch key)
	l.Info(fmt.Sprintf("Reconciling Dogs with foo value: %s (key: %s)", fooValue, req.Name))

	// List all Dogs with the specified foo value using the field indexer
	// Important: Use the actual foo value (without prefix) for the field selector
	var dogs pseudoclusterscopekeyexamplecomv1alpha1.DogList
	if err := r.List(ctx, &dogs,
		client.MatchingFields{idxFoo: fooValue}); err != nil {
		l.Error(err, "failed to list Dogs by foo value", "foo", fooValue)
		return ctrl.Result{}, err
	}

	l.Info(fmt.Sprintf("Found %d Dogs with foo value: %s", len(dogs.Items), fooValue))

	// Process each Dog with the specified foo value
	for _, dog := range dogs.Items {
		l.Info("Processing Dog", "name", dog.Name, "namespace", dog.Namespace, "foo", dog.Spec.Foo)
	}

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager using the BatchKey pattern.
func (r *DogReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		// Disable `For` to use the BatchKey pattern
		// For(&pseudoclusterscopekeyexamplecomv1alpha1.Dog{}).
		// Watch Dog resources and use MapFunc to create batch keys
		Watches(&pseudoclusterscopekeyexamplecomv1alpha1.Dog{},
			handler.EnqueueRequestsFromMapFunc(func(_ context.Context, obj client.Object) []reconcile.Request {
				dog := obj.(*pseudoclusterscopekeyexamplecomv1alpha1.Dog)
				// Create a batch key with prefix: Namespace is empty, Name contains the prefixed foo value
				key := types.NamespacedName{Name: prefixFoo + dog.Spec.Foo}
				return []reconcile.Request{{NamespacedName: key}}
			})).
		WithOptions(controller.Options{
			MaxConcurrentReconciles: 8, // Different foo values can be processed in parallel (max 8)
		}).
		Named("dog").
		Complete(r)
}
