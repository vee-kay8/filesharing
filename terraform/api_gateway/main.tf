# --- 1. REST API and Data Sources ---
resource "aws_api_gateway_rest_api" "file_share_api" {
  name        = "FileShareAPI"
  description = "API for file uploading and sharing"
}

# --- 2. Cognito Authorizer (Security) ---
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name                   = "CognitoAuthorizer"
  rest_api_id            = aws_api_gateway_rest_api.file_share_api.id
  type                   = "COGNITO_USER_POOLS"
  identity_source        = "method.request.header.Authorization" # Standard JWT token header
  provider_arns          = [var.cognito_user_pool_arn]
}

# --- 3. Resources ---

# /upload
resource "aws_api_gateway_resource" "upload" {
  rest_api_id = aws_api_gateway_rest_api.file_share_api.id
  parent_id   = aws_api_gateway_rest_api.file_share_api.root_resource_id
  path_part   = "upload"
}

# /download
resource "aws_api_gateway_resource" "download" {
  rest_api_id = aws_api_gateway_rest_api.file_share_api.id
  parent_id   = aws_api_gateway_rest_api.file_share_api.root_resource_id
  path_part   = "download"
}

# /download/{file_key} - Resource for the path parameter
resource "aws_api_gateway_resource" "file_key" {
  rest_api_id = aws_api_gateway_rest_api.file_share_api.id
  parent_id   = aws_api_gateway_resource.download.id
  path_part   = "{file_key}"
}

# /presign
resource "aws_api_gateway_resource" "presign" {
  rest_api_id = aws_api_gateway_rest_api.file_share_api.id
  parent_id   = aws_api_gateway_rest_api.file_share_api.root_resource_id
  path_part   = "presign"
}

# --- 4. Methods and Integrations ---

# UPLOAD (POST /upload)
resource "aws_api_gateway_method" "upload_post" {
  rest_api_id    = aws_api_gateway_rest_api.file_share_api.id
  resource_id    = aws_api_gateway_resource.upload.id
  http_method    = "POST"
  authorization  = "COGNITO_USER_POOLS" # Secured
  authorizer_id  = aws_api_gateway_authorizer.cognito_authorizer.id
}

resource "aws_api_gateway_integration" "upload_integration" {
  rest_api_id             = aws_api_gateway_rest_api.file_share_api.id
  resource_id             = aws_api_gateway_resource.upload.id
  http_method             = aws_api_gateway_method.upload_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.upload_lambda_arn}/invocations"
}

# DOWNLOAD (GET /download/{file_key})
resource "aws_api_gateway_method" "download_get" {
  rest_api_id        = aws_api_gateway_rest_api.file_share_api.id
  resource_id        = aws_api_gateway_resource.file_key.id
  http_method        = "GET"
  authorization      = "COGNITO_USER_POOLS" # Secured
  authorizer_id      = aws_api_gateway_authorizer.cognito_authorizer.id
  request_parameters = {
    "method.request.path.file_key" = true # Required path parameter
  }
}

resource "aws_api_gateway_integration" "download_integration" {
  rest_api_id             = aws_api_gateway_rest_api.file_share_api.id
  resource_id             = aws_api_gateway_resource.file_key.id
  http_method             = aws_api_gateway_method.download_get.http_method
  integration_http_method = "POST" 
  type                    = "AWS_PROXY"
  uri = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.download_lambda_arn}/invocations"
  
  # Map path parameter to the Lambda event
  request_parameters = {
    "integration.request.path.file_key" = "method.request.path.file_key"
  }
}

# PRESIGN (GET /presign)
resource "aws_api_gateway_method" "presign_get" {
  rest_api_id        = aws_api_gateway_rest_api.file_share_api.id
  resource_id        = aws_api_gateway_resource.presign.id
  http_method        = "GET"
  authorization      = "COGNITO_USER_POOLS" # Secured
  authorizer_id      = aws_api_gateway_authorizer.cognito_authorizer.id
  request_parameters = {
    "method.request.querystring.file_name" = true # Required query parameter
  }
}

resource "aws_api_gateway_integration" "presign_integration" {
  rest_api_id             = aws_api_gateway_rest_api.file_share_api.id
  resource_id             = aws_api_gateway_resource.presign.id
  http_method             = aws_api_gateway_method.presign_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.presign_lambda_arn}/invocations"
}

# --- 5. Deployment ---

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.file_share_api.id
  
  # Force a redeployment when any method/integration changes
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.upload_integration.id,
      aws_api_gateway_integration.download_integration.id,
      aws_api_gateway_integration.presign_integration.id,
    ]))
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.file_share_api.id
  stage_name    = "v1"
}