output "presign_lambda_arn" {
  description = "The ARN of the presign URL Lambda function."
  # Ensure the resource name (presign_function) matches the one in lambda/main.tf
  value       = aws_lambda_function.presign_function.arn
}
# FILESHARING/terraform/lambda/outputs.tf (Add these two new outputs)

output "upload_function_name" {
  description = "The name of the file upload Lambda function."
  value       = aws_lambda_function.upload_function.function_name
}

output "download_function_name" {
  description = "The name of the file download Lambda function."
  value       = aws_lambda_function.download_function.function_name
}

# You already have "presign_lambda_arn" but we need the name too:
output "presign_function_name" {
  description = "The name of the presign Lambda function."
  value       = aws_lambda_function.presign_function.function_name
}

# Also expose ARNs for upload/download to be used by API Gateway module
output "upload_lambda_arn" {
  description = "The ARN of the upload Lambda function."
  value       = aws_lambda_function.upload_function.arn
}

output "download_lambda_arn" {
  description = "The ARN of the download Lambda function."
  value       = aws_lambda_function.download_function.arn
}