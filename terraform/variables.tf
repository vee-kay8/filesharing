variable "s3_bucket_name" {
  description = "The name of the S3 bucket for file storage"
  type        = string
}

variable "cognito_user_pool_name" {
  description = "The name of the Cognito User Pool"
  type        = string
}

variable "cognito_identity_pool_name" {
  description = "The name of the Cognito Identity Pool"
  type        = string
}

variable "api_gateway_name" {
  description = "The name of the API Gateway"
  type        = string
}

variable "lambda_function_name" {
  description = "The name of the Lambda function"
  type        = string
}

variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}