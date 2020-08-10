// Code generated by mockery v1.0.0. DO NOT EDIT.

package mocks

import (
	types "github.com/aws/aws-controllers-k8s/pkg/types"
	mock "github.com/stretchr/testify/mock"

	v1alpha1 "github.com/aws/aws-controllers-k8s/apis/core/v1alpha1"
)

// AWSResourceManagerFactory is an autogenerated mock type for the AWSResourceManagerFactory type
type AWSResourceManagerFactory struct {
	mock.Mock
}

// ManagerFor provides a mock function with given fields: _a0, _a1
func (_m *AWSResourceManagerFactory) ManagerFor(_a0 types.AWSResourceReconciler, _a1 v1alpha1.AWSAccountID) (types.AWSResourceManager, error) {
	ret := _m.Called(_a0, _a1)

	var r0 types.AWSResourceManager
	if rf, ok := ret.Get(0).(func(types.AWSResourceReconciler, v1alpha1.AWSAccountID) types.AWSResourceManager); ok {
		r0 = rf(_a0, _a1)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(types.AWSResourceManager)
		}
	}

	var r1 error
	if rf, ok := ret.Get(1).(func(types.AWSResourceReconciler, v1alpha1.AWSAccountID) error); ok {
		r1 = rf(_a0, _a1)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// ResourceDescriptor provides a mock function with given fields:
func (_m *AWSResourceManagerFactory) ResourceDescriptor() types.AWSResourceDescriptor {
	ret := _m.Called()

	var r0 types.AWSResourceDescriptor
	if rf, ok := ret.Get(0).(func() types.AWSResourceDescriptor); ok {
		r0 = rf()
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(types.AWSResourceDescriptor)
		}
	}

	return r0
}
