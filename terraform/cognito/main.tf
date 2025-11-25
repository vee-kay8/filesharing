resource "aws_cognito_user_pool" "user_pool" {
  name = "file-share-app-user-pool"

  lambda_config {
    # CORRECTED: Use the input variable
    pre_sign_up = var.presign_lambda_arn 
  }

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "file-share-app-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  generate_secret      = false
  allowed_oauth_flows  = ["code"]
  allowed_oauth_scopes = ["email", "openid"]
  callback_urls        = ["http://localhost:8000/callback"]
  logout_urls          = ["https://localhost:8000/logout"]
}

resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name               = "file-share-app-identity-pool"
  allow_unauthenticated_identities = true

  cognito_identity_providers {
    provider_name = aws_cognito_user_pool.user_pool.endpoint
    client_id     = aws_cognito_user_pool_client.user_pool_client.id
  }
}

resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.user_pool.id
  username     = "testuser@example.com"
  attributes = {
    email = "testuser@example.com"
  }
  password             = "Password123!"
  force_alias_creation = false
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "cognito_identity_pool_id" {
  value = aws_cognito_identity_pool.identity_pool.id
}