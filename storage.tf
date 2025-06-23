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

# S3 bucket access logging
resource "aws_s3_bucket_logging" "schedule_bucket_logging" {
  bucket = aws_s3_bucket.schedule_files.id

  target_bucket = aws_s3_bucket.s3_logs_bucket.id
  target_prefix = "access-logs/schedule-files/"
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "schedule_bucket_lifecycle" {
  bucket = aws_s3_bucket.schedule_files.id

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

# Enable server-side encryption for the S3 bucket using KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "schedule_encryption" {
  bucket = aws_s3_bucket.schedule_files.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_encryption_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
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
  billing_mode = "PROVISIONED"  # Change to provisioned for autoscaling
  read_capacity  = 5
  write_capacity = 5
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
    read_capacity      = 5
    write_capacity     = 5
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_key.arn  # Use customer-managed KMS key
  }

  tags = {
    Name        = "ScheduleHistoryTable"
    Description = "Stores history of schedule generation executions"
  }
}

# DynamoDB Autoscaling for Read Capacity
resource "aws_appautoscaling_target" "dynamodb_table_read_target" {
  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/${aws_dynamodb_table.schedule_history.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

# DynamoDB Autoscaling for Write Capacity
resource "aws_appautoscaling_target" "dynamodb_table_write_target" {
  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/${aws_dynamodb_table.schedule_history.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

# DynamoDB Autoscaling Policy for Read Capacity
resource "aws_appautoscaling_policy" "dynamodb_table_read_policy" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_read_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_read_target.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_read_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_read_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

# DynamoDB Autoscaling Policy for Write Capacity
resource "aws_appautoscaling_policy" "dynamodb_table_write_policy" {
  name               = "DynamoDBWriteCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_write_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_write_target.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_write_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_write_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}

