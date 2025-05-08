# AWS WAF Web ACL for CloudFront
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  name        = "cloudfront-waf-protection"
  description = "WAF Web ACL for CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Core rule set
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known bad inputs
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # Geo-restriction rule (optional - uncomment if needed)
  # rule {
  #   name     = "GeoRestrictionRule"
  #   priority = 3
  #
  #   action {
  #     block {}
  #   }
  #
  #   statement {
  #     geo_match_statement {
  #       country_codes = ["RU", "CN", "NK", "IR"]
  #     }
  #   }
  #
  #   visibility_config {
  #     cloudwatch_metrics_enabled = true
  #     metric_name                = "GeoRestrictionRule"
  #     sampled_requests_enabled   = true
  #   }
  # }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cloudfront-waf-protection"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "CloudFront-WAF-Protection"
    Environment = terraform.workspace
  }
}

# CloudWatch logging for WAF
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = "/aws/waf/cloudfront-waf-logs"
  retention_in_days = 30

  tags = {
    Name        = "WAF-CloudFront-Logs"
    Environment = terraform.workspace
  }
}

# WAF logging configuration
# Comment out the WAF logging configuration for now as it requires Firehose setup
# resource "aws_wafv2_web_acl_logging_configuration" "waf_logging" {
#   resource_arn            = aws_wafv2_web_acl.cloudfront_waf.arn
#   log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]
# }

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Output the WAF Web ACL ARN
output "waf_web_acl_arn" {
  value       = aws_wafv2_web_acl.cloudfront_waf.arn
  description = "ARN of the WAF Web ACL protecting CloudFront"
}