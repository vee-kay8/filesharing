variable "upload_lambda_arn" {
  description = "The ARN of the upload Lambda function."
  type        = string
}

variable "download_lambda_arn" {
  description = "The ARN of the download Lambda function."
  type        = string
}

variable "presign_lambda_arn" {
  description = "The ARN of the presign Lambda function."
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "The ARN of the Cognito User Pool for authorization."
  type        = string
}

variable "aws_account_id" {
  description = "The AWS account ID for ARN construction."
  type        = string
}

variable "aws_region" {
  description = "The AWS region for ARN construction."
  type        = string
}

variable "options_lambda_arn" {
  description = "The ARN of the OPTIONS handler Lambda function."
  type        = string
}