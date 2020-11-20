#!/usr/bin/env bash

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="$THIS_DIR/../../.."
SCRIPTS_DIR="$ROOT_DIR/scripts"

. $SCRIPTS_DIR/lib/common.sh
. $SCRIPTS_DIR/lib/aws.sh

# lambda_function_exists() returns 0 if a lambda Function with the supplied name
# exists, 1 otherwise.
#
# Usage:
#
#   if ! lambda_function_exist "$function_name"; then
#       echo "Function $function_name does not exist!"
#   fi
lambda_function_exists() {
    __function_name="$1"
    daws lambda get-function --function-name "$__function_name" --output json >/dev/null 2>&1
    if [[ $? -eq 254 ]]; then
        return 1
    else
        return 0
    fi
}

lambda_function_jq() {
    __lambda_name="$1"
    __jq_query="$2"
    json=$( daws ecr get-lambda --function-name "$__lambda_name" --output json || exit 1 )
    echo "$json" | jq --raw-output $__jq_query
}

# lambda_function_alias_exists() returns 0 if a lambda Function Alias with the supplied name
# exists, 1 otherwise.
#
# Usage:
#
#   if ! lambda_function_alias_exists "$repo_name"; then
#       echo "Alias $lambda_function_alias_exist does not exist!"
#   fi
lambda_function_alias_exists() {
    __function_name="$1"
    __alias_name="$2"
    daws lambda get-alias --function-name "$__function_name" "$__alias_name" --output json >/dev/null 2>&1
    if [[ $? -eq 254 ]]; then
        return 1
    else
        return 0
    fi
}

# lambda_function_alias_exists() returns 0 if a lambda Function Alias with the supplied name
# exists, 1 otherwise.
lambda_setup_iam_role() {
  if [[ $# -ne 1 ]]; then
    echo "FATAL: expected one argument"
    echo "Usage: lambda_setup_iam_role $role_name"
    exit 1
  fi

  local __role_name="$1"
  aws iam create-role --role-name "$__role_name" --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  assert_equal "0" "$?" "Expected success from aws iam create-role --role-name $__role_name but got $?" || exit 1

  aws iam attach-role-policy --role-name "$__role_name" --policy-arn 'arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess' >/dev/null
  assert_equal "0" "$?" "Expected success from aws iam attach-role --role-name $__role_name but got $?" || exit 1
}

lambda_cleanup_iam_role() {
  if [[ $# -ne 1 ]]; then
    echo "FATAL: expected one argument"
    echo "Usage: lambda_cleanup_iam_role role_name"
    exit 1
  fi

  local __role_name="$1"
  daws iam detach-role-policy --role-name "$__role_name" --policy-arn "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess" >/dev/null
  assert_equal "0" "$?" "Expected success from aws iam detach-role-policy --role-name $__role_name but got $?" || exit 1

  daws iam delete-role --role-name "$__role_name" >/dev/null
  assert_equal "0" "$?" "Expected success from aws iam delete-role --role-name $__role_name but got $?" || exit 1
}