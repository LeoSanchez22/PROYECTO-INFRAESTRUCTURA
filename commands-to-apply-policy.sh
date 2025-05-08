#!/bin/bash

# Create the IAM policy
aws iam create-policy \
    --policy-name TerraformDeploymentPolicy \
    --policy-document file://terraform-required-permissions.json

# Get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Attach the policy to your user
aws iam attach-user-policy \
    --user-name Leonardo \
    --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/TerraformDeploymentPolicy

echo "Policy has been created and attached to user Leonardo"
echo "You can now run terraform apply again"

