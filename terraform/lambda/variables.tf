variable "s3_bucket_arn" {
  description = "The ARN of the S3 bucket passed from the root module."
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket passed from the root module."
  type        = string
}

# NEW: Variable to accept the Cognito User Pool ID
variable "cognito_user_pool_id" {
  description = "The ID of the Cognito User Pool."
  type        = string
}