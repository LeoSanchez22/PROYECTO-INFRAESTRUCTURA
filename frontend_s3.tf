# S3 bucket for frontend assets
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "leocorp-frontend-${terraform.workspace}"
  
  tags = {
    Name        = "Frontend Bucket"
    Environment = terraform.workspace
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
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }
  }
}

# S3 bucket website configuration
resource "aws_s3_bucket_website_configuration" "frontend_bucket_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Event notifications for frontend bucket (additional configuration)
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

