# AWS Certificate Manager (ACM) Certificate for CloudFront
# Note: CloudFront requires certificates to be in us-east-1 region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Variables needed for ACM
variable "domain_name" {
  description = "Domain name for the CloudFront distribution"
  type        = string
  default     = "example.com" # Replace with your actual domain
}

variable "use_dns_validation" {
  description = "Whether to use DNS validation for the certificate (requires Route53 zone). If false, email validation will be used."
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the domain (only needed if use_dns_validation is true)"
  type        = string
  default     = ""
}

variable "use_provided_certificate" {
  description = "Whether to use a provided certificate ARN instead of creating a new one"
  type        = bool
  default     = false
}

variable "provided_certificate_arn" {
  description = "ARN of an existing ACM certificate (only used if use_provided_certificate is true)"
  type        = string
  default     = ""
}

# ACM Certificate - with conditional validation method
resource "aws_acm_certificate" "cloudfront_cert" {
  count             = var.use_provided_certificate ? 0 : 1
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = var.use_dns_validation ? "DNS" : "EMAIL"
  
  # Add subject alternative names if needed
  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  tags = {
    Name        = "CloudFront-Certificate"
    Environment = "production"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# DNS Validation Records - Only created if DNS validation is enabled
resource "aws_route53_record" "cert_validation" {
  for_each = var.use_dns_validation && !var.use_provided_certificate ? {
    for dvo in aws_acm_certificate.cloudfront_cert[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Certificate Validation - Only performed if DNS validation is enabled
resource "aws_acm_certificate_validation" "cert_validation" {
  count                   = var.use_dns_validation && !var.use_provided_certificate ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront_cert[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Outputs
output "acm_certificate_arn" {
  value       = var.use_provided_certificate ? var.provided_certificate_arn : (length(aws_acm_certificate.cloudfront_cert) > 0 ? aws_acm_certificate.cloudfront_cert[0].arn : null)
  description = "The ARN of the ACM certificate"
}

output "acm_certificate_status" {
  value       = var.use_provided_certificate ? "IMPORTED" : (length(aws_acm_certificate.cloudfront_cert) > 0 ? aws_acm_certificate.cloudfront_cert[0].status : null)
  description = "The status of the ACM certificate"
}

# Local value for certificate ARN to use in CloudFront
locals {
  certificate_arn = var.use_provided_certificate ? var.provided_certificate_arn : (length(aws_acm_certificate.cloudfront_cert) > 0 ? aws_acm_certificate.cloudfront_cert[0].arn : null)
}

