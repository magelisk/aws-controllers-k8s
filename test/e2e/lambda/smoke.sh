#!/usr/bin/env bash

set -e pipefail

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ARTIFACTS_DIR="$THIS_DIR/artifacts"
ROOT_DIR="$THIS_DIR/../../.."
BUILD_DIR="$ROOT_DIR/build"
BUILD_DAWS_DIR="/aws/build"
SCRIPTS_DIR="$ROOT_DIR/scripts"

source "$SCRIPTS_DIR/lib/common.sh"
source "$SCRIPTS_DIR/lib/aws.sh"
source "$SCRIPTS_DIR/lib/aws/s3.sh"
source "$SCRIPTS_DIR/lib/aws/sqs.sh"
source "$SCRIPTS_DIR/lib/aws/lambda.sh"
source "$SCRIPTS_DIR/lib/k8s.sh"
source "$SCRIPTS_DIR/lib/testutil.sh"

AWS_ACCOUNT_ID=$( aws_account_id )
wait_seconds=10
test_name="$( filenoext "${BASH_SOURCE[0]}" )"
service_name="lambda"
ack_ctrl_pod_id=123

debug_msg "executing test: $service_name/$test_name"

# THIS IS SO MESSY MFIX IT
function_name="ack-test-smoke-function"
function_artifact="lambda.zip"
function_role_name="ack-lambda-controller-smoke-tests-function-role"
function_resource_name="function/$function_name"

alias_name="ack-test-smoke-alias"
alias_version='$LATEST'
alias_resource_name="alias/$alias_name"

event_source_mapping_name="ack-test-smoke-sqs-event-source-mapping"
event_source_mapping_resource_name="eventsourcemapping/$event_source_mapping_name"

sqs_queue_name=test-queue

# PRE-CHECKS
if lambda_function_exists "$function_name"; then
    echo "FAIL: expected $function_name to not exist in Lambda. Did previous test run cleanup?"
    exit 1
fi

if k8s_resource_exists "$resource_name"; then
    echo "FAIL: expected $resource_name to not exist. Did previous test run cleanup?"
    exit 1
fi

# Create S3 bucket
bucket_name="ack-test-smoke-$service_name-$RANDOM"

# Deploy lambda code
GOOS=linux GOARCH=amd64 go build -o $BUILD_DIR/lambda $ARTIFACTS_DIR/lambda.go
zip -j $BUILD_DIR/lambda.zip $BUILD_DIR/lambda

s3_create_bucket $bucket_name $AWS_REGION
daws s3 cp $BUILD_DIR/lambda.zip s3://$bucket_name > /dev/null

lambda_setup_iam_role $function_role_name

cat <<EOF | kubectl apply -f - 2>/dev/null
apiVersion: lambda.services.k8s.aws/v1alpha1
kind: Function
metadata:
  name: $function_name
  namespace: default
spec:
  code:
    s3Bucket: $bucket_name
    s3Key: $function_artifact
  description: lambda created by ack lambda controller
  functionName: $function_name
  handler: lambda
  runtime: go1.x
  role: arn:aws:iam::$AWS_ACCOUNT_ID:role/$function_role_name
EOF

sleep $wait_seconds

debug_msg "checking function $function_name created in Lambda"
if ! lambda_function_exists "$function_name"; then
    echo "FAIL: expected $function_name to have been created in Lambda"
    kubectl logs -n ack-system "$ack_ctrl_pod_id"
    exit 1
fi

cat <<EOF | kubectl apply -f - 2>/dev/null
apiVersion: lambda.services.k8s.aws/v1alpha1
kind: Alias
metadata:
  name: $alias_name
  namespace: default
spec:
  functionName: $function_name
  functionVersion: $alias_version
  name: $alias_name
  description: "alias description"
EOF

sleep $wait_seconds

debug_msg "checking alias $alias_name created in Lambda"
if ! lambda_function_alias_exists $function_name "$alias_name"; then
    echo "FAIL: expected $alias_name to have been created in Lambda"
    kubectl logs -n ack-system "$ack_ctrl_pod_id"
    exit 1
fi

kubectl delete $alias_resource_name 2>/dev/null
assert_equal "0" "$?" "Expected success from kubectl delete but got $?" || exit 1



sleep $wait_seconds

if lambda_function_alias_exists "$function_name"; then
    echo "FAIL: expected $function_name to be deleted in Lambda"
    kubectl logs -n ack-system "$ack_ctrl_pod_id"
    exit 1
fi

cat <<EOF | kubectl apply -f - 2>/dev/null
apiVersion: lambda.services.k8s.aws/v1alpha1
kind: EventSourceMapping
metadata:
  name: $event_source_mapping_name
  namespace: default
spec:
  functionName: $function_name
  eventSourceARN: arn:aws:sqs:eu-west-2:771174509839:testq
  batchSize: 5
EOF

lambda_cleanup_iam_role $function_role_name
assert_pod_not_restarted $ack_ctrl_pod_id