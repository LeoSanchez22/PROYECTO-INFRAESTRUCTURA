# S3 bucket for frontend assets
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "leocorp-frontend-${terraform.workspace}"
  
  tags = {
    Name        = "Frontend Bucket"
    Environment = terraform.workspace
  }
}

# Get the current AWS account ID
data "aws_caller_identity" "current" {}

# Configure server-side encryption for S3 bucket using Amazon S3-managed keys (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_bucket_encryption" {
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket ACL
resource "aws_s3_bucket_ownership_controls" "frontend_bucket_ownership" {
  bucket = aws_s3_bucket.frontend_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for CloudFront access
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
  depends_on = [aws_s3_bucket_public_access_block.frontend_bucket_access]
}

data "aws_iam_policy_document" "s3_policy" {
  # Primary statement: Allow CloudFront OAI access
  statement {
    sid       = "AllowCloudFrontOAIAccess"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.frontend_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }

  # Allow the bucket owner to perform actions on the objects
  statement {
    sid       = "AllowBucketOperations"
    effect    = "Allow"
    actions   = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["${aws_s3_bucket.frontend_bucket.arn}/*"]
    
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Security statement: Allow only HTTPS requests
  statement {
    sid       = "AllowSSLRequestsOnly"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.frontend_bucket.arn,
      "${aws_s3_bucket.frontend_bucket.arn}/*"
    ]
    
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# S3 bucket CORS configuration
resource "aws_s3_bucket_cors_configuration" "frontend_bucket_cors" {
  bucket = aws_s3_bucket.frontend_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]  # In production, limit this to your actual domains
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Output the bucket name for use in scripts and CI/CD
output "frontend_bucket_name" {
  value = aws_s3_bucket.frontend_bucket.id
  description = "Name of the S3 bucket hosting the frontend content"
}

# Event notifications commented out to simplify configuration
# Uncomment and configure SNS topic separately when needed
/*
resource "aws_s3_bucket_notification" "frontend_bucket_events" {
  bucket = aws_s3_bucket.frontend_bucket.id

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
    filter_suffix = ".html"
  }

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".js"
  }

  topic {
    topic_arn     = aws_sns_topic.s3_event_notification.arn
    events        = ["s3:ObjectCreated:*"]
    filter_suffix = ".css"
  }

  depends_on = [aws_sns_topic_policy.s3_notification_policy]
}
*/

