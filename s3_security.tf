# KMS key for S3 bucket encryption
resource "aws_kms_key" "s3_encryption_key" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "s3-encryption-key"
  }
}

# Create an SNS topic for S3 event notifications
resource "aws_sns_topic" "s3_event_notification" {
  name = "s3-event-notification-topic"
}

# SNS topic policy to allow S3 to publish messages
resource "aws_sns_topic_policy" "s3_notification_policy" {
  arn = aws_sns_topic.s3_event_notification.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = "SNS:Publish"
        Resource = aws_sns_topic.s3_event_notification.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = [
              aws_s3_bucket.frontend_bucket.arn,
              aws_s3_bucket.demo_bucket.arn,
              aws_s3_bucket.s3_logs_bucket.arn,
              aws_s3_bucket.cloudfront_logs.arn
            ]
          }
        }
      }
    ]
  })
}

# Output for the SNS topic
output "s3_event_notification_topic_arn" {
  value       = aws_sns_topic.s3_event_notification.arn
  description = "The ARN of the SNS topic for S3 event notifications"
}

resource "aws_kms_alias" "s3_encryption_key_alias" {
  name          = "alias/s3-encryption-key"
  target_key_id = aws_kms_key.s3_encryption_key.key_id
}

# Logging bucket for S3 access logs
resource "aws_s3_bucket" "s3_logs_bucket" {
  bucket = "s3-access-logs-${terraform.workspace}"

  tags = {
    Name        = "S3 Access Logs Bucket"
    Environment = terraform.workspace
  }
}

# Enable versioning for logs bucket
resource "aws_s3_bucket_versioning" "s3_logs_bucket_versioning" {
  bucket = aws_s3_bucket.s3_logs_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Configure logging for the logs bucket (yes, logging the access to the logs bucket)
resource "aws_s3_bucket_logging" "s3_logs_bucket_logging" {
  bucket = aws_s3_bucket.s3_logs_bucket.id

  target_bucket = aws_s3_bucket.s3_logs_bucket.id
  target_prefix = "logs-bucket-self-logs/"
}

# Block public access for logs bucket
resource "aws_s3_bucket_public_access_block" "logs_bucket_access" {
  bucket = aws_s3_bucket.s3_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encryption for logs bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_bucket_encryption" {
  bucket = aws_s3_bucket.s3_logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Lifecycle for logs bucket (retain logs for compliance)
resource "aws_s3_bucket_lifecycle_configuration" "logs_bucket_lifecycle" {
  bucket = aws_s3_bucket.s3_logs_bucket.id

  rule {
    id = "log-retention"
    status = "Enabled"
    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365 # 1 year retention
    }
  }
}

# Add abort incomplete multipart uploads to logs bucket lifecycle
resource "aws_s3_bucket_lifecycle_configuration" "logs_bucket_lifecycle_abort" {
  bucket = aws_s3_bucket.s3_logs_bucket.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"
    filter {
      prefix = ""
    }
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Event notifications for logs bucket
resource "aws_s3_bucket_notification" "logs_bucket_notification" {
  bucket = aws_s3_bucket.s3_logs_bucket.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix = ".log"
  }

  depends_on = [aws_sns_topic_policy.s3_notification_policy]
}

# ---------------- DEMO BUCKET SECURITY CONFIGURATIONS ----------------

# Correct public access settings for demo_bucket
resource "aws_s3_bucket_public_access_block" "demo_bucket_access_secure" {
  bucket = aws_s3_bucket.demo_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  # This will override the existing resource with the same name in S3.tf
}

# Server-side encryption for demo_bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "demo_bucket_encryption" {
  bucket = aws_s3_bucket.demo_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Versioning for demo_bucket
resource "aws_s3_bucket_versioning" "demo_bucket_versioning" {
  bucket = aws_s3_bucket.demo_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Access logging for demo_bucket
resource "aws_s3_bucket_logging" "demo_bucket_logging" {
  bucket = aws_s3_bucket.demo_bucket.id

  target_bucket = aws_s3_bucket.s3_logs_bucket.id
  target_prefix = "demo-bucket-logs/"
}

# Lifecycle configuration for demo_bucket
resource "aws_s3_bucket_lifecycle_configuration" "demo_bucket_lifecycle" {
  bucket = aws_s3_bucket.demo_bucket.id

  rule {
    id     = "transition-to-infrequent-access"
    status = "Enabled"
    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }

  rule {
    id     = "archive-old-objects"
    status = "Enabled"
    filter {
      prefix = ""
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }
  }

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Event notifications for demo bucket
resource "aws_s3_bucket_notification" "demo_bucket_notification" {
  bucket = aws_s3_bucket.demo_bucket.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectAcl:Put"]
  }

  depends_on = [aws_sns_topic_policy.s3_notification_policy]
}

# ---------------- FRONTEND BUCKET SECURITY CONFIGURATIONS ----------------

# Server-side encryption for frontend_bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_bucket_encryption" {
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Versioning for frontend_bucket
resource "aws_s3_bucket_versioning" "frontend_bucket_versioning" {
  bucket = aws_s3_bucket.frontend_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Access logging for frontend_bucket
resource "aws_s3_bucket_logging" "frontend_bucket_logging" {
  bucket = aws_s3_bucket.frontend_bucket.id

  target_bucket = aws_s3_bucket.s3_logs_bucket.id
  target_prefix = "frontend-bucket-logs/"
}

# Lifecycle configuration for frontend_bucket
resource "aws_s3_bucket_lifecycle_configuration" "frontend_bucket_lifecycle" {
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    id     = "transition-to-infrequent-access"
    status = "Enabled"
    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }
  }

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Event notifications for frontend bucket
resource "aws_s3_bucket_notification" "frontend_bucket_notification" {
  bucket = aws_s3_bucket.frontend_bucket.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*", "s3:ObjectAcl:Put"]
  }

  depends_on = [aws_sns_topic_policy.s3_notification_policy]
}

# Cross-region replication for disaster recovery (optional but recommended)
resource "aws_s3_bucket_replication_configuration" "frontend_bucket_replication" {
  # Depends on bucket versioning
  depends_on = [aws_s3_bucket_versioning.frontend_bucket_versioning]

  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    id     = "frontend-bucket-replication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.frontend_bucket_replica.arn
      storage_class = "STANDARD"
    }
  }
}

# Replica bucket in another region
resource "aws_s3_bucket" "frontend_bucket_replica" {
  provider = aws.replica
  bucket   = "leocorp-frontend-replica-${terraform.workspace}"

  tags = {
    Name        = "Frontend Bucket Replica"
    Environment = terraform.workspace
  }
}

# Server-side encryption for frontend_bucket_replica
resource "aws_s3_bucket_server_side_encryption_configuration" "replica_bucket_encryption" {
  provider = aws.replica
  bucket = aws_s3_bucket.frontend_bucket_replica.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# Versioning for frontend_bucket_replica (required for replication)
resource "aws_s3_bucket_versioning" "replica_bucket_versioning" {
  provider = aws.replica
  bucket = aws_s3_bucket.frontend_bucket_replica.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access for replica bucket
resource "aws_s3_bucket_public_access_block" "replica_bucket_access" {
  provider = aws.replica
  bucket = aws_s3_bucket.frontend_bucket_replica.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for replica_bucket
resource "aws_s3_bucket_lifecycle_configuration" "replica_bucket_lifecycle" {
  provider = aws.replica
  bucket = aws_s3_bucket.frontend_bucket_replica.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"
    filter {
      prefix = ""
    }
    
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# IAM role for replication
resource "aws_iam_role" "replication_role" {
  name = "s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for replication
resource "aws_iam_policy" "replication_policy" {
  name = "s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.frontend_bucket.arn]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.frontend_bucket.arn}/*"]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.frontend_bucket_replica.arn}/*"]
      }
    ]
  })
}

# Attach replication policy to role
resource "aws_iam_role_policy_attachment" "replication_attachment" {
  role       = aws_iam_role.replication_role.name
  policy_arn = aws_iam_policy.replication_policy.arn
}

# Provider for replica region
provider "aws" {
  alias  = "replica"
  region = "us-west-2" # Different region for disaster recovery
}

