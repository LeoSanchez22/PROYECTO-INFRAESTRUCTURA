#!/bin/bash

# Get the policy ARN
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='TerraformDeploymentPolicy'].Arn" --output text)

# Create a new version and set it as the default
aws iam create-policy-version \
    --policy-arn $POLICY_ARN \
    --policy-document file://terraform-required-permissions.json \
    --set-as-default

echo "TerraformDeploymentPolicy has been updated with new permissions"

