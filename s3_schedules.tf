# S3 bucket for storing generated PDF schedules
resource "aws_s3_bucket" "schedule_pdfs" {
  bucket = "schedule-pdfs-${terraform.workspace}-${random_string.bucket_suffix.result}"
  
  tags = {
    Name        = "SchedulePDFs"
    Environment = terraform.workspace
  }
}

# Generate a random suffix for globally unique S3 bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "schedule_pdfs_ownership" {
  bucket = aws_s3_bucket.schedule_pdfs.id
  
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Block public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "schedule_pdfs_access" {
  bucket = aws_s3_bucket.schedule_pdfs.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "schedule_pdfs_versioning" {
  bucket = aws_s3_bucket.schedule_pdfs.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "schedule_pdfs_encryption" {
  bucket = aws_s3_bucket.schedule_pdfs.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Configure lifecycle rules for the S3 bucket
resource "aws_s3_bucket_lifecycle_configuration" "schedule_pdfs_lifecycle" {
  bucket = aws_s3_bucket.schedule_pdfs.id
  
  rule {
    id     = "archive-old-pdfs"
    status = "Enabled"
    
    filter {
      prefix = ""  # Empty prefix means apply to all objects
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
      days = 365
    }
  }
}

# CORS configuration for the S3 bucket
resource "aws_s3_bucket_cors_configuration" "schedule_pdfs_cors" {
  bucket = aws_s3_bucket.schedule_pdfs.id
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]  # In production, restrict to your domain
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
