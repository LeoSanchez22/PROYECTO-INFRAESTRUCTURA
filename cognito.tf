resource "aws_cognito_user_pool" "user_pool" {
  name = "leocorp"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  auto_verified_attributes = ["email"]
  alias_attributes         = ["email"]
}

resource "aws_cognito_user_pool_client" "client" {
  name = "web-app-client"

  user_pool_id = aws_cognito_user_pool.user_pool.id
  
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  generate_secret = false
}

# Domain for Cognito Hosted UI
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "leocorp-auth-domain"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

