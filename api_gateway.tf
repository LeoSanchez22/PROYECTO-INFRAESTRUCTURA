### API Gateway Configuration ###

# Create API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "lambda-api-gateway"
  description = "API Gateway to invoke Lambda function"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Create API Gateway Resource (endpoint path)
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "schedule"  # This is the path after the API URL (e.g., /schedule)
}

# Create API Gateway Method (HTTP method)
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"  # Using POST as the HTTP method for our Lambda function
  authorization = "NONE"  # Can be changed to "COGNITO_USER_POOLS" if using Cognito
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
  value = "${aws_api_gateway_deployment.deployment.invoke_url}${aws_api_gateway_stage.stage.stage_name}/${aws_api_gateway_resource.resource.path_part}"
  description = "URL to access the API Gateway endpoint"
}

# Add CloudWatch logs for API Gateway
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"  # All resources and methods
  depends_on  = [aws_api_gateway_account.api_gateway_account]

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = true  # Enables detailed logging
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
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

