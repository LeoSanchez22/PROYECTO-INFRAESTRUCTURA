# Outputs for the entire infrastructure

# S3 Outputs
output "s3_website_bucket_name" {
  value       = aws_s3_bucket.frontend_bucket.id
  description = "Name of the S3 bucket hosting the website"
}

output "s3_website_endpoint" {
  value       = aws_s3_bucket_website_configuration.frontend_bucket_website.website_endpoint
  description = "S3 website endpoint"
}

output "schedule_pdfs_bucket_name" {
  value       = aws_s3_bucket.schedule_pdfs.id
  description = "Name of the S3 bucket for storing generated PDF schedules"
}

# CloudFront Outputs
output "cloudfront_distribution_domain" {
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
  description = "Domain name of the CloudFront distribution"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.frontend_distribution.id
  description = "ID of the CloudFront distribution"
}

# WAF Outputs
output "waf_web_acl_name" {
  value       = aws_wafv2_web_acl.cloudfront_waf.name
  description = "Name of the WAF Web ACL protecting CloudFront"
}

output "waf_web_acl_id" {
  value       = aws_wafv2_web_acl.cloudfront_waf.id
  description = "ID of the WAF Web ACL"
}

# AppSync Outputs
output "appsync_graphql_endpoint" {
  value       = aws_appsync_graphql_api.main.uris["GRAPHQL"]
  description = "GraphQL endpoint URL for the AppSync API"
}

# Lambda Outputs
output "lambda_function_name" {
  value       = aws_lambda_function.my_lambda.function_name
  description = "Name of the Lambda function"
}

output "lambda_function_arn" {
  value       = aws_lambda_function.my_lambda.arn
  description = "ARN of the Lambda function"
}

output "lambda_trigger_ecs_function_name" {
  value       = aws_lambda_function.trigger_ecs_task.function_name
  description = "Name of the Lambda function that triggers ECS tasks"
}

# Cognito Outputs
output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.user_pool.id
  description = "ID of the Cognito User Pool"
}

output "cognito_app_client_id" {
  value       = aws_cognito_user_pool_client.client.id
  description = "ID of the Cognito User Pool Client"
}

output "cognito_hosted_ui_url" {
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
  description = "URL for Cognito Hosted UI"
}

# ECR Outputs
output "ecr_repository_url" {
  value       = aws_ecr_repository.schedule_generator.repository_url
  description = "URL of the ECR repository for the schedule generator Docker image"
}

# ECS Outputs
output "ecs_cluster_name" {
  value       = aws_ecs_cluster.schedule_cluster.name
  description = "Name of the ECS cluster"
}

output "ecs_task_definition_arn" {
  value       = aws_ecs_task_definition.schedule_generator.arn
  description = "ARN of the ECS task definition"
}

# DynamoDB Outputs
output "dynamodb_table_name" {
  value       = aws_dynamodb_table.schedule_history.name
  description = "Name of the DynamoDB table for schedule history"
}

# VPC Outputs
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID of the VPC"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "IDs of the private subnets"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs of the public subnets"
}

# Complete Infrastructure URL
output "website_url" {
  value       = "https://${aws_cloudfront_distribution.frontend_distribution.domain_name}"
  description = "URL to access the website through CloudFront"
}

# Docker Push Commands
output "docker_push_commands" {
  value = <<EOF
# Build and push the Docker image to ECR:
# 1. Authenticate Docker to ECR:
aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.schedule_generator.repository_url}

# 2. Build the Docker image:
cd docker
docker build -t ${aws_ecr_repository.schedule_generator.repository_url}:latest .

# 3. Push the image to ECR:
docker push ${aws_ecr_repository.schedule_generator.repository_url}:latest
EOF
  description = "Commands to build and push Docker image to ECR"
}