# AppSync API
resource "aws_appsync_graphql_api" "main" {
  name                = "frontend-api"
  authentication_type = "AMAZON_COGNITO_USER_POOLS"
  
  user_pool_config {
    default_action = "ALLOW"
    user_pool_id   = aws_cognito_user_pool.user_pool.id
    app_id_client_regex = aws_cognito_user_pool_client.client.id
  }

  # Optional: Add additional authentication methods if needed
  # additional_authentication_provider {
  #   authentication_type = "API_KEY"
  # }

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs_role.arn
    field_log_level          = "ERROR" # Options: ERROR, ALL, NONE
  }

  schema = <<EOF
type Query {
  getData: String
}

type Mutation {
  processData(input: String!): String
}

schema {
  query: Query
  mutation: Mutation
}
EOF

  tags = {
    Name        = "Frontend-API"
    Environment = terraform.workspace
  }
}

# IAM role for AppSync logging
resource "aws_iam_role" "appsync_logs_role" {
  name = "appsync-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for AppSync logging
resource "aws_iam_role_policy" "appsync_logs_policy" {
  name = "appsync-logs-policy"
  role = aws_iam_role.appsync_logs_role.id

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

# AppSync Lambda Data Source
resource "aws_appsync_datasource" "lambda_datasource" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "LambdaDataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda_role.arn

  lambda_config {
    function_arn = aws_lambda_function.my_lambda.arn
  }
}

# IAM role for AppSync to invoke Lambda
resource "aws_iam_role" "appsync_lambda_role" {
  name = "appsync-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for AppSync to invoke Lambda
resource "aws_iam_role_policy" "appsync_lambda_policy" {
  name = "appsync-lambda-policy"
  role = aws_iam_role.appsync_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = aws_lambda_function.my_lambda.arn
      }
    ]
  })
}

# AppSync Resolver for Query.getData
resource "aws_appsync_resolver" "get_data_resolver" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Query"
  field       = "getData"
  data_source = aws_appsync_datasource.lambda_datasource.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "operation": "Invoke",
  "payload": {
    "field": "getData",
    "arguments": $utils.toJson($context.arguments)
  }
}
EOF

  response_template = "$util.toJson($context.result)"
}

# AppSync Resolver for Mutation.processData
resource "aws_appsync_resolver" "process_data_resolver" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Mutation"
  field       = "processData"
  data_source = aws_appsync_datasource.lambda_datasource.name

  request_template = <<EOF
{
  "version": "2018-05-29",
  "operation": "Invoke",
  "payload": {
    "field": "processData",
    "arguments": $utils.toJson($context.arguments)
  }
}
EOF

  response_template = "$util.toJson($context.result)"
}

# Output the AppSync API URL
output "appsync_api_url" {
  value       = aws_appsync_graphql_api.main.uris["GRAPHQL"]
  description = "URL of the AppSync GraphQL API"
}

# Output the AppSync API ID
output "appsync_api_id" {
  value       = aws_appsync_graphql_api.main.id
  description = "ID of the AppSync GraphQL API"
}