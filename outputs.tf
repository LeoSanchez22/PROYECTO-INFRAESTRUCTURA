output "bucket_name" {
  value = aws_s3_bucket.frontend_bucket.bucket
  description = "Name of the frontend S3 bucket"
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.frontend_distribution.domain_name
  description = "CloudFront distribution domain name"
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
  description = "Cognito User Pool ID"
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.client.id
  description = "Cognito User Pool Client ID"
}

output "cognito_domain" {
  value = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
  description = "Cognito hosted UI domain"
}

