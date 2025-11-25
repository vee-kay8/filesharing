output "file_bucket_name" {
  description = "The name/ID of the S3 file upload bucket."
  value       = aws_s3_bucket.file_upload_bucket.bucket
}

output "file_bucket_arn" {
  description = "The ARN of the S3 file upload bucket."
  value       = aws_s3_bucket.file_upload_bucket.arn
}

output "s3_bucket_name" {
  description = "The ID of the S3 file upload bucket."
  value       = aws_s3_bucket.file_upload_bucket.id
}