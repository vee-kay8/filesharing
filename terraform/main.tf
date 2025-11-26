# FILESHARING/terraform/main.tf

# --- 1. Call the S3 Module ---
module "s3_storage" {
  source = "./s3"
}

# --- 2. Call the Cognito Module (Creates the User Pool first) ---
module "cognito" {
  source = "./cognito"

  # This output is needed by the Lambda module to grant permission
  presign_lambda_arn = module.lambda_functions.presign_lambda_arn
}

# --- 3. Call the Lambda Module ---
module "lambda_functions" {
  source = "./lambda" 

  s3_bucket_arn  = module.s3_storage.file_bucket_arn
  s3_bucket_name = module.s3_storage.file_bucket_name
  
  # NEW: Pass the Cognito User Pool ID back to Lambda for the permission resource
  cognito_user_pool_id = module.cognito.cognito_user_pool_id 
}