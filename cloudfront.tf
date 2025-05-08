# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Distribution for frontend application"
  default_root_object = "index.html"
  
  # Origin configuration for S3 bucket (Web UI)
  origin {
    domain_name = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id   = "S3-frontend"
    
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }
  
  # Origin configuration for AppSync API
  origin {
    domain_name = replace(replace(aws_appsync_graphql_api.main.uris["GRAPHQL"], "https://", ""), "/graphql", "")
    origin_id   = "AppSync-API"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }
  
  # Default cache behavior for S3 content (Web UI)
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
  }
  
  # Cache behavior for AppSync API
  ordered_cache_behavior {
    path_pattern     = "/graphql*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "AppSync-API"
    
    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "x-api-key"]
      cookies {
        forward = "all"
      }
    }
    
    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }
  
  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  
  # SSL Certificate
  viewer_certificate {
    cloudfront_default_certificate = true
    # Use this instead if you have a custom domain
    # acm_certificate_arn = aws_acm_certificate.cert.arn
    # ssl_support_method = "sni-only"
  }
  
  # Custom error responses
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
  
  # Associate with WAF Web ACL
  web_acl_id = aws_wafv2_web_acl.cloudfront_waf.arn
  
  # Add price class
  price_class = "PriceClass_100"
  
  # Add tags
  tags = {
    Environment = terraform.workspace
    Name        = "Frontend-Distribution"
  }
}

# Origin Access Identity for CloudFront
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for frontend website"
}

# Output for CloudFront domain name
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.frontend_distribution.domain_name
}

# Current AWS region data source
data "aws_region" "current" {}
