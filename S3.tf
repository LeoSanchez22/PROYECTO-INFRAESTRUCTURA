resource "aws_s3_bucket" "demo_bucket" {
  bucket = "demo-bucket-leonardo"

  tags = {
    Name        = "Demo Bucket Leonardo"
  }
}

resource "aws_s3_bucket_public_access_block" "demo_bucket_access" {
  bucket = aws_s3_bucket.demo_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.demo_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.demo_bucket_access]
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject"],
        Resource  = "${aws_s3_bucket.demo_bucket.arn}/*"
      }
    ]
   })
}

