# FILESHARING/terraform/main.tf

# Global Data Sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --- 1. Call the S3 Module ---
module "s3_storage" {
  source = "./s3"
}

# --- 2. Call the Lambda Module (First) ---
# Defines the Lambdas and uses the API Gateway ID for permissions
module "lambda_functions" {
  source = "./lambda"

  s3_bucket_arn        = module.s3_storage.file_bucket_arn
  s3_bucket_name       = module.s3_storage.file_bucket_name
  cognito_user_pool_id = module.cognito.cognito_user_pool_id
}

# --- 3. Call the Cognito Module ---
module "cognito" {
  source = "./cognito"

  presign_lambda_arn = module.lambda_functions.presign_lambda_arn
}

# --- 4. Call the API Gateway Module (Last) ---
# Depends on Lambdas and Cognito for ARNs
module "api_gateway" {
  source = "./api_gateway"

  # Inputs from Lambda Module
  upload_lambda_arn   = module.lambda_functions.upload_lambda_arn
  download_lambda_arn = module.lambda_functions.download_lambda_arn
  presign_lambda_arn  = module.lambda_functions.presign_lambda_arn
  options_lambda_arn  = module.lambda_functions.options_lambda_arn

  # Inputs from Cognito Module
  cognito_user_pool_arn = module.cognito.cognito_user_pool_arn

  # Inputs for ARN construction (from data sources)
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.name
}

# Final Output (Optional)
output "api_base_url" {
  value = module.api_gateway.base_url
}
# FILESHARING/terraform/main.tf (Add these permissions at the end)

# --- Grant API Gateway Permission to Invoke Lambdas ---

resource "aws_lambda_permission" "apigw_upload_permission" {
  statement_id = "AllowAPIGatewayInvokeUpload"
  action       = "lambda:InvokeFunction"
  # Reference the new function name output
  function_name = module.lambda_functions.upload_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.api_gateway.rest_api_id}/*/*"
}

resource "aws_lambda_permission" "apigw_download_permission" {
  statement_id  = "AllowAPIGatewayInvokeDownload"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_functions.download_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.api_gateway.rest_api_id}/*/*"
}

resource "aws_lambda_permission" "apigw_presign_permission" {
  statement_id  = "AllowAPIGatewayInvokePresign"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_functions.presign_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.api_gateway.rest_api_id}/*/*"
}

resource "aws_lambda_permission" "apigw_options_permission" {
  statement_id  = "AllowAPIGatewayInvokeOptions"
  action        = "lambda:InvokeFunction"
  function_name = "options_handler_function"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${module.api_gateway.rest_api_id}/*/*"
}