# CloudFront Distribution with Security Enhancements
# - WAF Protection (via waf.tf)
# - TLS 1.2+ with modern cipher suites
# - Access logging to S3
resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Distribution for frontend application with security enhancements"
  default_root_object = "index.html"
  
  # Associate with AWS WAF Web ACL
  web_acl_id          = aws_wafv2_web_acl.cloudfront_waf.arn
  
  # Origin configuration (S3 bucket assumed, adjust as needed)
  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = "S3-frontend"
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }
  
  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-frontend"
    
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Referer", "Origin"]
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    
    # Optional - Lambda function association for authentication
    # lambda_function_association {
    #   event_type   = "viewer-request"
    #   lambda_arn   = aws_lambda_function.auth_lambda.qualified_arn
    #   include_body = false
    # }
  }
  
  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  # Enhanced SSL/TLS Configuration
  # - Uses custom ACM certificate
  # - Enforces TLS 1.2 or higher
  # - Implements SNI for multiple certificates support
  viewer_certificate {
    acm_certificate_arn      = local.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
    # Fallback to CloudFront default certificate if no custom certificate is provided
    cloudfront_default_certificate = local.certificate_arn == null ? true : false
  }
  
  # Access Logging Configuration
  # - Logs stored in dedicated S3 bucket with encryption
  # - Lifecycle policies manage log retention
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    prefix          = "cloudfront/"
  }
  
  # Optional: Custom error responses
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }
  
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }
  
  # Add price class
  price_class = "PriceClass_100"
  
  # Add tags
  tags = {
    Environment = "production"
    Name        = "Frontend-Distribution"
  }
}

# Origin Access Identity for CloudFront
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for frontend website"
}

# Outputs
output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.frontend_distribution.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.frontend_distribution.domain_name
}

# Current AWS region data source
data "aws_region" "current" {}

# Note: This output assumes Cognito User Pool has a domain configured.
# If not, you will need to add a domain to your Cognito User Pool configuration.
output "cognito_hosted_ui_url" {
  value = "https://${aws_cognito_user_pool.user_pool.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
  description = "URL for Cognito Hosted UI (requires domain configuration)"
}
