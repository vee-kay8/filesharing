resource "aws_s3_bucket" "file_upload_bucket" {
  bucket = "file-sharing-upload-fstf"



  lifecycle { prevent_destroy = false }

  tags = {
    Name        = "FileUploadBucket"
    Environment = "Development"
  }
}


resource "aws_s3_bucket_versioning" "file_upload_bucket_versioning" {
  bucket = aws_s3_bucket.file_upload_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "file_upload_bucket_pab" {
  bucket = aws_s3_bucket.file_upload_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}