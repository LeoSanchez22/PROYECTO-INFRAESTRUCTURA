# CloudFront logs bucket ownership controls (required for CloudFront logging)
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs_bucket_ownership" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Enable ACLs for CloudFront logs bucket
resource "aws_s3_bucket_acl" "cloudfront_logs_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs_bucket_ownership]
  
  bucket = aws_s3_bucket.cloudfront_logs.id
  acl    = "log-delivery-write"
}

# S3 Bucket for CloudFront Access Logs
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "cloudfront-access-logs-v2-${data.aws_caller_identity.current.account_id}-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "CloudFront-Access-Logs"
    Environment = "production"
  }
}

# Server-side encryption for the logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_encryption" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Enable versioning for the logs bucket
resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access for the logs bucket
resource "aws_s3_bucket_public_access_block" "logs_public_access_block" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy to allow CloudFront to deliver logs
resource "aws_s3_bucket_policy" "logs_bucket_policy" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudfront_logs.arn}/cloudfront/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "AllowSSLRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.cloudfront_logs.arn,
          "${aws_s3_bucket.cloudfront_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  # Ensure the bucket exists before attempting to apply the policy
  depends_on = [aws_s3_bucket.cloudfront_logs]
}

# Lifecycle rules for log rotation
resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    id     = "log-rotation"
    status = "Enabled"

    # Add filter to specify which objects this rule applies to
    # This addresses the warning about missing filter/prefix
    filter {
      prefix = "cloudfront/"
    }

    # Move logs to Infrequent Access storage class after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # Move logs to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # Expire (delete) logs after 365 days
    expiration {
      days = 365
    }

    # Add noncurrent version handling for versioned buckets
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }

  # Add a rule for incomplete multipart uploads
  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {
      prefix = "" # Empty prefix means apply to all objects
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Ensure the bucket exists before attempting to apply the lifecycle configuration
  depends_on = [aws_s3_bucket.cloudfront_logs]
}

# Access logging for the CloudFront logs bucket (logging about the logs)
resource "aws_s3_bucket_logging" "cloudfront_logs_bucket_logging" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  target_bucket = aws_s3_bucket.s3_logs_bucket.id
  target_prefix = "cloudfront-logs-bucket-logs/"
}

# Event notifications for the CloudFront logs bucket
resource "aws_s3_bucket_notification" "cloudfront_logs_notification" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix = ".log"
  }

  depends_on = [aws_sns_topic_policy.s3_notification_policy]
}


# Output for the logs bucket
output "cloudfront_logs_bucket" {
  value       = aws_s3_bucket.cloudfront_logs.bucket
  description = "The name of the S3 bucket for CloudFront access logs"
}

output "cloudfront_logs_bucket_domain_name" {
  value       = aws_s3_bucket.cloudfront_logs.bucket_regional_domain_name
  description = "The domain name of the CloudFront logs bucket"
}

