# AWS WAFv2 Web ACL Configuration for CloudFront
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  name  = "cloudfront-waf-protection-v2-${random_id.bucket_suffix.hex}"
  description = "WAF for CloudFront distribution with common security rules"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rule 1: AWS Managed Rules - Common Rule Set (SQLi, XSS, etc.)
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

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
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

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
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: Rate-based rule for DDoS protection
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
        # Standard 5-minute evaluation window
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: SQL Injection Prevention (additional layer)
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  tags = {
    Environment = "production"
    Name        = "CloudFront-WAF-Protection"
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "CloudFrontWAFWebACLMetric"
    sampled_requests_enabled   = true
  }
}

# CloudFront WAF association is handled directly in the CloudFront distribution
# through the web_acl_id parameter and does not require a separate association resource

# Outputs
output "waf_web_acl_id" {
  value       = aws_wafv2_web_acl.cloudfront_waf.id
  description = "The ID of the WAF Web ACL"
}

output "waf_web_acl_arn" {
  value       = aws_wafv2_web_acl.cloudfront_waf.arn
  description = "The ARN of the WAF Web ACL"
}

