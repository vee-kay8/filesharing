output "presign_lambda_arn" {
  description = "The ARN of the presign URL Lambda function."
  # Ensure the resource name (presign_function) matches the one in lamda/main.tf
  value       = aws_lambda_function.presign_function.arn
}