### API Gateway Configuration ###

# Get current AWS region
data "aws_region" "current" {}

# Create API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "lambda-api-gateway"
  description = "API Gateway to invoke Lambda function"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create Cognito User Pool for API authentication
resource "aws_cognito_user_pool" "api_user_pool" {
  name = "api-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]

  tags = {
    Name = "API User Pool"
  }
}

# Create Cognito User Pool Client
resource "aws_cognito_user_pool_client" "api_user_pool_client" {
  name         = "api-user-pool-client"
  user_pool_id = aws_cognito_user_pool.api_user_pool.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  generate_secret = false
}

# Create API Gateway Authorizer
resource "aws_api_gateway_authorizer" "my_cognito_authorizer" {
  name                   = "cognito-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.api.id
  type                   = "COGNITO_USER_POOLS"
  provider_arns          = [aws_cognito_user_pool.api_user_pool.arn]
  identity_source        = "method.request.header.Authorization"
}

# Create API Gateway Resource (endpoint path)
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "schedule"  # This is the path after the API URL (e.g., /schedule)
}

# Create request validator for API Gateway
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "request-validator"
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  validate_request_body       = true
  validate_request_parameters = true
}

# Create API Gateway Method (HTTP method)
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.my_cognito_authorizer.id
  
  # Add request validation
  request_validator_id = aws_api_gateway_request_validator.validator.id
  
  # Request parameters (if needed)
  request_parameters = {
    "method.request.header.Content-Type" = true
  }
}

# Create API Gateway Integration with Lambda
resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"  # Lambda requires POST for invocation
  type                    = "AWS_PROXY"  # AWS_PROXY uses Lambda proxy integration
  uri                     = aws_lambda_function.my_lambda.invoke_arn
}

# Set up Method Response for 200 status code
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# Set up Integration Response for the 200 status code
resource "aws_api_gateway_integration_response" "integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  # Depends on the integration to ensure proper setup
  depends_on = [
    aws_api_gateway_integration.integration
  ]
}

# Create deployment to make the API available
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  
  # Lifecycle policy to avoid deployment issues
  lifecycle {
    create_before_destroy = true
  }

  # Depends on all the gateway resources to ensure they exist before deployment
  depends_on = [
    aws_api_gateway_method.method,
    aws_api_gateway_integration.integration,
    aws_api_gateway_method_response.response_200,
    aws_api_gateway_integration_response.integration_response
  ]
}

# Create API Gateway Stage
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"  # Stage name, e.g., prod, dev, test
  
  # Enable X-Ray tracing
  xray_tracing_enabled = true
  
  # Enable caching
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"  # 0.5 GB cache
  
  # Access logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_access_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
  
  depends_on = [aws_cloudwatch_log_group.api_gateway_access_logs]
}

# CloudWatch Log Group for API Gateway access logs
resource "aws_cloudwatch_log_group" "api_gateway_access_logs" {
  name              = "/aws/apigateway/lambda-api-gateway-v2-${random_id.bucket_suffix.hex}/access-logs"
  retention_in_days = 365  # 1 year retention for compliance
  
  # Encrypt with KMS for security
  kms_key_id = aws_kms_key.logs_key.arn
  
  tags = {
    Name        = "API Gateway Access Logs"
    Environment = "production"
  }
}

# Grant Lambda permission to be invoked by API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # ARN of the API Gateway
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Output the API Gateway URL
output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.stage.stage_name}/${aws_api_gateway_resource.resource.path_part}"
  description = "URL to access the API Gateway endpoint"
}

# Output Cognito User Pool information
output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.api_user_pool.id
  description = "ID of the Cognito User Pool for API authentication"
}

output "cognito_user_pool_client_id" {
  value       = aws_cognito_user_pool_client.api_user_pool_client.id
  description = "ID of the Cognito User Pool Client"
}

# Add CloudWatch logs for API Gateway
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"  # All resources and methods
  # depends_on  = [aws_api_gateway_account.api_gateway_account]  # Commented out - account config disabled

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false  # Disabled for security (no sensitive data in logs)
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
    caching_enabled        = true
    cache_ttl_in_seconds   = 300
    cache_data_encrypted   = true
  }
}

# CloudWatch Metric Alarm for API Gateway 4xx errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  alarm_name          = "api-gateway-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors API Gateway 4XX errors"
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.api.name
    Stage   = aws_api_gateway_stage.stage.stage_name
  }
}

# CloudWatch Metric Alarm for API Gateway 5xx errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  
  dimensions = {
    ApiName = aws_api_gateway_rest_api.api.name
    Stage   = aws_api_gateway_stage.stage.stage_name
  }
}

