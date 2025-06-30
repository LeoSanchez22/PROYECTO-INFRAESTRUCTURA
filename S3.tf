resource "aws_s3_bucket" "demo_bucket" {
  bucket = "demo-bucket-leonardo-v2-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Frontend Bucket"
    Environment = terraform.workspace
  }
}

# S3 bucket versioning
resource "aws_s3_bucket_versioning" "demo_bucket_versioning" {
  bucket = aws_s3_bucket.demo_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "demo_bucket_encryption" {
  bucket = aws_s3_bucket.demo_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      # Cambiado a encriptación AES256 gratuita para desarrollo
      sse_algorithm = "AES256"
      # kms_master_key_id = aws_kms_key.s3_encryption_key.arn
    }
    # bucket_key_enabled removido - no necesario para AES256
  }
}

# S3 bucket access logging
resource "aws_s3_bucket_logging" "demo_bucket_logging" {
  bucket = aws_s3_bucket.demo_bucket.id

  target_bucket = aws_s3_bucket.s3_logs_bucket.id
  target_prefix = "access-logs/demo-bucket/"
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "demo_bucket_lifecycle" {
  bucket = aws_s3_bucket.demo_bucket.id

  rule {
    id     = "delete_incomplete_multipart_uploads"
    status = "Enabled"
    
    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition_old_versions"
    status = "Enabled"
    
    filter {
      prefix = ""
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# Note: This resource is being overridden by aws_s3_bucket_public_access_block.demo_bucket_access_secure in s3_security.tf
# Keeping it here for reference, but it will be replaced by the secure version
resource "aws_s3_bucket_public_access_block" "demo_bucket_access" {
  bucket = aws_s3_bucket.demo_bucket.id

  # These settings will be overridden by demo_bucket_access_secure
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Note: This policy allows public read access, which conflicts with the secure public access block settings
# We're replacing it with a more secure policy that restricts access to specific principals
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.demo_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.demo_bucket_access_secure]
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "RestrictedReadGetObject",
        Effect    = "Allow",
        Principal = {
          AWS = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        },
        Action    = ["s3:GetObject"],
        Resource  = "${aws_s3_bucket.demo_bucket.arn}/*"
      },
      {
        Sid       = "AllowSSLRequestsOnly",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [
          aws_s3_bucket.demo_bucket.arn,
          "${aws_s3_bucket.demo_bucket.arn}/*"
        ],
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

