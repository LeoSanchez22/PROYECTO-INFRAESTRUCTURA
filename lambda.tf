# IAM Role for Lambda with CloudWatch permissions
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role_v2_${random_id.bucket_suffix.hex}"

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
  name        = "lambda_logging_policy_v2_${random_id.bucket_suffix.hex}"
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

# IAM Policy for S3 and DynamoDB access
resource "aws_iam_policy" "lambda_storage_access" {
  name        = "lambda_storage_access_policy_v2_${random_id.bucket_suffix.hex}"
  description = "IAM policy for Lambda to access S3 and DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.schedule_files.arn,
          "${aws_s3_bucket.schedule_files.arn}/*"
        ]
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Effect = "Allow"
        Resource = [
          aws_dynamodb_table.schedule_history.arn,
          "${aws_dynamodb_table.schedule_history.arn}/index/*"
        ]
      }
    ]
  })
}

# Attach S3 and DynamoDB IAM policy to role
resource "aws_iam_role_policy_attachment" "lambda_storage" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_storage_access.arn
}

# IAM Policy for SQS Dead Letter Queue access
resource "aws_iam_policy" "lambda_sqs_access" {
  name        = "lambda_sqs_access_policy_v2_${random_id.bucket_suffix.hex}"
  description = "IAM policy for Lambda to send messages to SQS Dead Letter Queue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect = "Allow"
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

# Attach SQS IAM policy to role
resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sqs_access.arn
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.my_lambda.function_name}"
  retention_in_days = 365  # 1 year retention for compliance
  
  # Encrypt with KMS for security
  # kms_key_id comentado para usar encriptación AWS gratuita
  # kms_key_id = aws_kms_key.logs_key.arn
  
  tags = {
    Name        = "Lambda Function Logs"
    Environment = "production"
  }
  
  # Depends on the Lambda function to ensure proper naming
  depends_on = [aws_lambda_function.my_lambda]
}

# Dead Letter Queue for Lambda
resource "aws_sqs_queue" "lambda_dlq" {
  name = "lambda-dlq-v2-${random_id.bucket_suffix.hex}"
  
  # Encrypt SQS queue - comentado para usar encriptación AWS gratuita
  # kms_master_key_id = aws_kms_key.lambda_key.arn
  
  tags = {
    Name = "Lambda Dead Letter Queue"
  }
}

# Lambda Function
resource "aws_lambda_function" "my_lambda" {
  function_name = "my-lambda-function-v2-${random_id.bucket_suffix.hex}"
  # Path to the deployment package
  filename         = "dist/lambda_function.zip"
  source_code_hash = filebase64sha256("dist/lambda_function.zip")
  
  # Replace with your handler and runtime as needed
  handler = "index.handler"
  runtime = "nodejs20.x"  # Updated to non-deprecated runtime
  
  role = aws_iam_role.lambda_role.arn
  
  # Enable X-Ray tracing
  tracing_config {
    mode = "Active"
  }
  
  # Reserved concurrent executions not configured to avoid account limit issues
  
  # Configure Dead Letter Queue
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }
  
  environment {
    variables = {
      ENVIRONMENT    = "production"
      S3_BUCKET_NAME = aws_s3_bucket.schedule_files.id
      DYNAMODB_TABLE = aws_dynamodb_table.schedule_history.name
    }
  }
  
  # Encrypt environment variables with KMS - comentado para ahorrar costos
  # kms_key_arn = aws_kms_key.lambda_key.arn
  
  # Configure timeout and memory
  timeout     = 60
  memory_size = 256
  
  tags = {
    Name        = "Academic Schedule Lambda"
    Environment = "production"
  }
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

