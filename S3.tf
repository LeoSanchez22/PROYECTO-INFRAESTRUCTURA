resource "aws_s3_bucket" "demo_bucket" {
  bucket = "demo-bucket-leonardo"

  tags = {
    Name        = "Demo Bucket Leonardo"
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

