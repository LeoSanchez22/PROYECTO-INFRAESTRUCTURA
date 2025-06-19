# S3 bucket for storing generated academic schedules
resource "aws_s3_bucket" "schedule_files" {
  bucket = "academic-schedule-files-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "AcademicScheduleBucket"
    Description = "Stores generated academic schedule files"
  }
}

# Generate a random suffix for globally unique S3 bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Enable versioning on the S3 bucket
resource "aws_s3_bucket_versioning" "schedule_versioning" {
  bucket = aws_s3_bucket.schedule_files.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption for the S3 bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "schedule_encryption" {
  bucket = aws_s3_bucket.schedule_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enable CORS on the S3 bucket
resource "aws_s3_bucket_cors_configuration" "schedule_cors" {
  bucket = aws_s3_bucket.schedule_files.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"] # In production, restrict to your CloudFront distribution domain
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Public access block for S3 (prevent public access)
resource "aws_s3_bucket_public_access_block" "schedule_public_access_block" {
  bucket = aws_s3_bucket.schedule_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for storing schedule generation history
resource "aws_dynamodb_table" "schedule_history" {
  name         = "ScheduleGenerationHistory"
  billing_mode = "PAY_PER_REQUEST" # On-demand capacity
  hash_key     = "ExecutionId"
  range_key    = "Timestamp"

  attribute {
    name = "ExecutionId"
    type = "S"
  }

  attribute {
    name = "Timestamp"
    type = "S"
  }

  attribute {
    name = "UserId"
    type = "S"
  }

  global_secondary_index {
    name               = "UserIdIndex"
    hash_key           = "UserId"
    range_key          = "Timestamp"
    projection_type    = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "ScheduleHistoryTable"
    Description = "Stores history of schedule generation executions"
  }
}

