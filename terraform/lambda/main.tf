# FILESHARING/terraform/lambda/main.tf

# ADD THESE DATA SOURCES NEAR THE TOP
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
# Define the temporary directory for artifacts if it doesn't exist
resource "null_resource" "create_artifacts_dir" {
  provisioner "local-exec" {
    command = "mkdir -p artifacts"
  }
}

# --- 1. IAM Role and Policy (Access Control) ---
resource "aws_iam_role" "lambda_role" {
  name = "file_upload_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      },
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "file_upload_lambda_policy"
  description = "Policy for Lambda function to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = [
          "${var.s3_bucket_arn}/*",
          var.s3_bucket_arn,
          "arn:aws:logs:*:*:*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_policy.arn
  role       = aws_iam_role.lambda_role.name
}


## 📦 Automated Code Packaging

data "archive_file" "upload_zip" {
  type        = "zip"
  # FINAL CORRECTED PATH
  source_file = "../src/lambda/upload.py"
  output_path = "artifacts/upload.zip"
  depends_on  = [null_resource.create_artifacts_dir]
}

data "archive_file" "download_zip" {
  type        = "zip"
  # FINAL CORRECTED PATH
  source_file = "../src/lambda/download.py"
  output_path = "artifacts/download.zip"
  depends_on  = [null_resource.create_artifacts_dir]
}

data "archive_file" "presign_zip" {
  type        = "zip"
  # FINAL CORRECTED PATH
  source_file = "../src/lambda/presign.py"
  output_path = "artifacts/presign.zip"
  depends_on  = [null_resource.create_artifacts_dir]
}


## 🚀 Lambda Function Definitions

### Upload Function
resource "aws_lambda_function" "upload_function" {
  function_name = "upload_file_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "upload.lambda_handler"
  runtime       = "python3.8"
  timeout       = 30

  filename         = data.archive_file.upload_zip.output_path
  source_code_hash = data.archive_file.upload_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = var.s3_bucket_name 
    }
  }
}

### Download Function
resource "aws_lambda_function" "download_function" {
  function_name = "download_file_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "download.lambda_handler"
  runtime       = "python3.8"
  timeout       = 30

  filename         = data.archive_file.download_zip.output_path
  source_code_hash = data.archive_file.download_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = var.s3_bucket_name 
    }
  }
}

### Presign Function
resource "aws_lambda_function" "presign_function" {
  function_name = "presign_url_function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "presign.lambda_handler"
  runtime       = "python3.8"
  timeout       = 30

  filename         = data.archive_file.presign_zip.output_path
  source_code_hash = data.archive_file.presign_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = var.s3_bucket_name 
    }
  }
}
# ADD THIS PERMISSION RESOURCE AT THE BOTTOM
resource "aws_lambda_permission" "cognito_presign_permission" {
  statement_id  = "AllowCognitoToInvokePresignLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presign_function.function_name
  principal     = "cognito-idp.amazonaws.com"

  # Constructs the specific ARN for the Cognito User Pool
  source_arn    = "arn:aws:cognito-idp:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:userpool/${var.cognito_user_pool_id}"
}

# FILESHARING/terraform/lambda/main.tf (Add these at the end)

