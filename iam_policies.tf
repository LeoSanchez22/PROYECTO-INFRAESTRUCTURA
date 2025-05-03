# Create DynamoDB Administrators group
resource "aws_iam_group" "dynamodb_admins" {
  name = "dynamodb_administrators"
}

# Create the DynamoDB policy
resource "aws_iam_policy" "dynamodb_full_access" {
  name        = "dynamodb_full_access"
  description = "Policy for DynamoDB full access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:*",
          "dax:*",
          "application-autoscaling:DeleteScalingPolicy",
          "application-autoscaling:DeregisterScalableTarget",
          "application-autoscaling:DescribeScalableTargets",
          "application-autoscaling:DescribeScalingActivities",
          "application-autoscaling:DescribeScalingPolicies",
          "application-autoscaling:PutScalingPolicy",
          "application-autoscaling:RegisterScalableTarget",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:GetMetricData",
          "datapipeline:ActivatePipeline",
          "datapipeline:CreatePipeline",
          "datapipeline:DeletePipeline",
          "datapipeline:DescribeObjects",
          "datapipeline:DescribePipelines",
          "datapipeline:GetPipelineDefinition",
          "datapipeline:ListPipelines",
          "datapipeline:PutPipelineDefinition",
          "datapipeline:QueryObjects",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "iam:GetRole",
          "iam:ListRoles",
          "kms:DescribeKey",
          "kms:ListAliases",
          "sns:CreateTopic",
          "sns:DeleteTopic",
          "sns:ListSubscriptions",
          "sns:ListSubscriptionsByTopic",
          "sns:ListTopics",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:SetTopicAttributes",
          "lambda:CreateFunction",
          "lambda:ListFunctions",
          "lambda:ListEventSourceMappings",
          "lambda:CreateEventSourceMapping",
          "lambda:DeleteEventSourceMapping",
          "lambda:GetFunctionConfiguration",
          "lambda:DeleteFunction"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to group
resource "aws_iam_group_policy_attachment" "dynamodb_admin_policy" {
  group      = aws_iam_group.dynamodb_admins.name
  policy_arn = aws_iam_policy.dynamodb_full_access.arn
}

# Additionally, attach the AWS managed policy for DynamoDB full access
resource "aws_iam_group_policy_attachment" "dynamodb_full_access_managed" {
  group      = aws_iam_group.dynamodb_admins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Add user to group
resource "aws_iam_user_group_membership" "dynamodb_admin_user" {
  user = "dsanchezc9@upao.edu.pe"
  groups = [aws_iam_group.dynamodb_admins.name]
}

# Also attach the AWS managed policy directly to the user
resource "aws_iam_user_policy_attachment" "user_dynamodb_full_access" {
  user       = "dsanchezc9@upao.edu.pe"
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
