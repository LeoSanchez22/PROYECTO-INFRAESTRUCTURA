# IAM Role for Lambda with CloudWatch permissions
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for CloudWatch Logs
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging_policy"
  description = "IAM policy for logging from Lambda to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach IAM policy to role
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# IAM Policy for S3 access
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda_s3_policy"
  description = "IAM policy for Lambda to access S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:GetObjectTagging"
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_s3_bucket.demo_bucket.arn}",
          "${aws_s3_bucket.demo_bucket.arn}/*",
          "${aws_s3_bucket.frontend_bucket.arn}",
          "${aws_s3_bucket.frontend_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach S3 policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.my_lambda.function_name}"
  retention_in_days = 14
  # Depends on the Lambda function to ensure proper naming
  depends_on = [aws_lambda_function.my_lambda]
}

# Lambda Function
resource "aws_lambda_function" "my_lambda" {
  function_name = "my-lambda-function"
  # Replace with your code package location
  filename         = "lambda_function.zip" # Create this file or use S3 bucket
  source_code_hash = filebase64sha256("lambda_function.zip")
  
  # Replace with your handler and runtime as needed
  handler = "index.handler"
  runtime = "nodejs18.x"
  
  role = aws_iam_role.lambda_role.arn
  
  environment {
    variables = {
      ENVIRONMENT = "production",
      DYNAMODB_TABLE = aws_dynamodb_table.data_table.name,
      MAX_FILE_SIZE = "20971520"  # 20MB
    }
  }
  
  # Configure timeout and memory - increased for better performance
  timeout     = 60
  memory_size = 256
}

# CloudWatch Metric Alarm for Lambda Errors
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "${aws_lambda_function.my_lambda.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This metric monitors lambda function errors"
  
  dimensions = {
    FunctionName = aws_lambda_function.my_lambda.function_name
  }
  
  # Optional: Add SNS actions for notification
  # alarm_actions     = [aws_sns_topic.lambda_alerts.arn]
  # ok_actions        = [aws_sns_topic.lambda_alerts.arn]
  # insufficient_data_actions = [aws_sns_topic.lambda_alerts.arn]
}

# CloudWatch Metric Alarm for Lambda Throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttle_alarm" {
  alarm_name          = "${aws_lambda_function.my_lambda.function_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This metric monitors lambda function throttles"
  
  dimensions = {
    FunctionName = aws_lambda_function.my_lambda.function_name
  }
  
  # Optional: Add SNS actions for notification
  # alarm_actions     = [aws_sns_topic.lambda_alerts.arn]
  # ok_actions        = [aws_sns_topic.lambda_alerts.arn]
  # insufficient_data_actions = [aws_sns_topic.lambda_alerts.arn]
}

# CloudWatch Dashboard for Lambda
resource "aws_cloudwatch_dashboard" "lambda_dashboard" {
  dashboard_name = "lambda-monitoring-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.my_lambda.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.my_lambda.function_name],
            ["AWS/Lambda", "Throttles", "FunctionName", aws_lambda_function.my_lambda.function_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Lambda Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.my_lambda.function_name, {"stat": "Average"}],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.my_lambda.function_name, {"stat": "Maximum"}]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Lambda Duration"
          period  = 300
        }
      }
    ]
  })
}

# S3 bucket notification configuration for demo bucket
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.demo_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.my_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"  # Optional: filter by prefix
    filter_suffix       = ".json"     # Optional: filter by suffix
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

# Permission for S3 to invoke Lambda
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.demo_bucket.arn
}

# Add CloudWatch alarm for Lambda duration
resource "aws_cloudwatch_metric_alarm" "lambda_duration_alarm" {
  alarm_name          = "${aws_lambda_function.my_lambda.function_name}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Maximum"
  threshold           = 50000  # 50 seconds (in milliseconds)
  alarm_description   = "This metric monitors lambda function duration"
  
  dimensions = {
    FunctionName = aws_lambda_function.my_lambda.function_name
  }
}
