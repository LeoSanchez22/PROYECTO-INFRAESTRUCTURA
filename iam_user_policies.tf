# IAM Policies for Leonardo User - DISABLED
# 
# NOTA: El usuario Leonardo ya tiene las políticas necesarias configuradas 
# manualmente en AWS, incluyendo los permisos de API Gateway en TerraformDeploymentPolicy.
# Esta configuración está comentada para evitar conflictos con el límite de políticas por usuario.
#
# # Reference to the existing IAM user 'Leonardo'
# data "aws_iam_user" "leonardo" {
#   user_name = "Leonardo"
# }
# 
# # Consolidated Infrastructure Management Policy for Leonardo
# resource "aws_iam_policy" "leonardo_infrastructure_full_policy" {
#   name        = "leonardo-infrastructure-full-access"
#   description = "Consolidated full access policy for Leonardo user - All AWS services for infrastructure management"
# 
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "FullAPIGatewayAccess"
#         Effect = "Allow"
#         Action = [
#           "apigateway:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullSQSAccess"
#         Effect = "Allow"
#         Action = [
#           "sqs:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullDynamoDBAccess"
#         Effect = "Allow"
#         Action = [
#           "dynamodb:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullLambdaAccess"
#         Effect = "Allow"
#         Action = [
#           "lambda:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullS3Access"
#         Effect = "Allow"
#         Action = [
#           "s3:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullCloudWatchLogsAccess"
#         Effect = "Allow"
#         Action = [
#           "logs:*",
#           "cloudwatch:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullCloudFrontAccess"
#         Effect = "Allow"
#         Action = [
#           "cloudfront:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullKMSAccess"
#         Effect = "Allow"
#         Action = [
#           "kms:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullCognitoAccess"
#         Effect = "Allow"
#         Action = [
#           "cognito-idp:*",
#           "cognito-identity:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullRoute53ACMAccess"
#         Effect = "Allow"
#         Action = [
#           "route53:*",
#           "acm:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "FullWAFAccess"
#         Effect = "Allow"
#         Action = [
#           "wafv2:*",
#           "waf:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "ApplicationAutoScalingAccess"
#         Effect = "Allow"
#         Action = [
#           "application-autoscaling:*"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "IAMManagementAccess"
#         Effect = "Allow"
#         Action = [
#           "iam:CreateRole",
#           "iam:DeleteRole",
#           "iam:AttachRolePolicy",
#           "iam:DetachRolePolicy",
#           "iam:CreatePolicy",
#           "iam:DeletePolicy",
#           "iam:GetRole",
#           "iam:GetPolicy",
#           "iam:GetUser",
#           "iam:ListAttachedRolePolicies",
#           "iam:ListAttachedUserPolicies",
#           "iam:AttachUserPolicy",
#           "iam:DetachUserPolicy",
#           "iam:PassRole",
#           "iam:CreateInstanceProfile",
#           "iam:DeleteInstanceProfile",
#           "iam:AddRoleToInstanceProfile",
#           "iam:RemoveRoleFromInstanceProfile"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "STSAccess"
#         Effect = "Allow"
#         Action = [
#           "sts:GetCallerIdentity",
#           "sts:AssumeRole"
#         ]
#         Resource = "*"
#       },
#       {
#         Sid    = "EC2BasicAccess"
#         Effect = "Allow"
#         Action = [
#           "ec2:DescribeInstances",
#           "ec2:DescribeSecurityGroups",
#           "ec2:DescribeVpcs",
#           "ec2:DescribeSubnets",
#           "ec2:CreateTags"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }
# 
# # Attach the consolidated policy to Leonardo user
# resource "aws_iam_user_policy_attachment" "leonardo_infrastructure_attachment" {
#   user       = data.aws_iam_user.leonardo.user_name
#   policy_arn = aws_iam_policy.leonardo_infrastructure_full_policy.arn
# }
# 
# # Output consolidated policy ARN for reference
# output "leonardo_infrastructure_policy" {
#   value = {
#     policy_arn = aws_iam_policy.leonardo_infrastructure_full_policy.arn
#     policy_name = aws_iam_policy.leonardo_infrastructure_full_policy.name
#     user_name = data.aws_iam_user.leonardo.user_name
#   }
#   description = "Consolidated infrastructure policy attached to Leonardo user"
# }
