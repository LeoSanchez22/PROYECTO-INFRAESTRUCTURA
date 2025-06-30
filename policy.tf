# API Gateway IAM Policy

# Policy document for API Gateway management
data "aws_iam_policy_document" "api_gateway_policy_document" {
  statement {
    sid    = "AllowFullAPIGatewayAccess"
    effect = "Allow"
    actions = [
      "apigateway:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowAPIGatewaySpecificOperations"
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT",
      "apigateway:PATCH",
      "apigateway:DELETE",
      "apigateway:UpdateRestApiPolicy"
    ]
    resources = [
      "arn:aws:apigateway:*::/restapis",
      "arn:aws:apigateway:*::/restapis/*",
      "arn:aws:apigateway:*::/apis",
      "arn:aws:apigateway:*::/apis/*"
    ]
  }

  statement {
    sid    = "AllowTaggingOperations"
    effect = "Allow"
    actions = [
      "apigateway:GET",
      "apigateway:POST",
      "apigateway:PUT", 
      "apigateway:PATCH",
      "apigateway:DELETE",
      "apigateway:TagResource",
      "apigateway:UntagResource"
    ]
    resources = [
      "arn:aws:apigateway:*::/tags/*",
      "arn:aws:apigateway:*::/tags",
      "arn:aws:apigateway:*::/restapis/*/tags",
      "arn:aws:apigateway:*::/restapis/*/tags/*"
    ]
  }

  statement {
    sid    = "AllowCloudWatchForAPIGateway"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:PutMetricData",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowLambdaIntegration"
    effect = "Allow"
    actions = [
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:GetFunction",
      "lambda:InvokeFunction"
    ]
    resources = ["*"]
  }
}

# IAM Role for API Gateway CloudWatch Logging
resource "aws_iam_role" "api_gateway_cloudwatch_role" {
  name = "api-gateway-cloudwatch-role-v2-${random_id.bucket_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "API Gateway CloudWatch Role"
  }
}

# API Gateway CloudWatch Logs Policy
resource "aws_iam_policy" "api_gateway_cloudwatch_policy" {
  name        = "api-gateway-cloudwatch-policy-v2-${random_id.bucket_suffix.hex}"
  description = "IAM policy for API Gateway to write to CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/apigateway/*",
          "arn:aws:logs:*:*:log-group:/aws/apigateway/*:*",
          "arn:aws:logs:*:*:log-group:/aws/lambda/*",
          "arn:aws:logs:*:*:log-group:/aws/lambda/*:*"
        ]
      }
    ]
  })
}

# Attach the CloudWatch Logs Policy to the API Gateway Role
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_attachment" {
  role       = aws_iam_role.api_gateway_cloudwatch_role.name
  policy_arn = aws_iam_policy.api_gateway_cloudwatch_policy.arn
}

# Configure API Gateway Account to use the CloudWatch Role
# NOTE: Commented out due to permission issues - can be enabled when Leonardo user has full admin permissions
# resource "aws_api_gateway_account" "api_gateway_account" {
#   cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch_role.arn
# }

# Create the IAM policy
resource "aws_iam_policy" "api_gateway_management_policy" {
  name        = "api-gateway-management-policy-v2-${random_id.bucket_suffix.hex}"
  description = "Policy for managing API Gateway resources"
  policy      = data.aws_iam_policy_document.api_gateway_policy_document.json
}

# If the user is using an IAM role, attach the policy to it
# This assumes you have an existing IAM role defined elsewhere in your Terraform
resource "aws_iam_role_policy_attachment" "api_gateway_policy_attachment" {
  role       = aws_iam_role.lambda_role.name  # Using the existing Lambda role for now
  policy_arn = aws_iam_policy.api_gateway_management_policy.arn
}

# Note: Leonardo user policies are now managed in iam_user_policies.tf

# Output the policy ARN for reference
output "api_gateway_policy_arn" {
  value       = aws_iam_policy.api_gateway_management_policy.arn
  description = "The ARN of the API Gateway management policy"
}

