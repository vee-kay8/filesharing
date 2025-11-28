output "rest_api_id" {
  description = "The API Gateway REST API id for the FileShareAPI."
  value       = aws_api_gateway_rest_api.file_share_api.id
}

output "stage_name" {
  description = "The stage name created for the API Gateway deployment."
  value       = aws_api_gateway_stage.api_stage.stage_name
}

output "base_url" {
  description = "Base invoke URL for the API Gateway stage."
  # Construct the standard Execute-API invoke URL
  value = "https://${aws_api_gateway_rest_api.file_share_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}"
}
