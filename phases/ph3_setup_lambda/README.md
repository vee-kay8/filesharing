# Phase 3: Setup Lambda Functions

This document outlines the steps for setting up and deploying the Lambda functions for the file uploading and sharing system.

## Overview

AWS Lambda functions provide the serverless compute layer for our application. They handle:
- **File Upload**: Receives base64-encoded files and stores them in S3
- **File Download**: Retrieves files from S3 and returns them base64-encoded
- **Presigned URLs**: Generates temporary URLs for secure file sharing
- **OPTIONS Handler**: Manages CORS preflight requests

## Architecture

```
API Gateway → Lambda Functions → S3 Bucket
              ↓
         CloudWatch Logs (monitoring)
```

## Prerequisites

✅ **Phase 1 Complete**: S3 bucket created (`file-sharing-upload-fstf`)  
✅ **Phase 2 Complete**: Cognito User Pool configured  
✅ **AWS CLI configured** with Lambda permissions  
✅ **Required IAM Permissions**:
   - `lambda:CreateFunction`
   - `lambda:UpdateFunctionCode`
   - `iam:CreateRole`
   - `iam:AttachRolePolicy`
   - `s3:PutObject`, `s3:GetObject` (for Lambda execution role)

## Lambda Functions Overview

### 1. Upload Function (`upload.py`)

**Purpose**: Handles file uploads from the frontend

**Key Features**:
- Accepts base64-encoded file content in JSON body
- Handles API Gateway's base64 encoding of request bodies
- Extracts filename from headers (case-insensitive)
- Uploads binary data to S3
- Returns success/error responses with CORS headers

**Environment Variables**:
- `BUCKET_NAME`: S3 bucket for file storage

### 2. Download Function (`download.py`)

**Purpose**: Retrieves files from S3

**Key Features**:
- Accepts file key from path parameters
- URL-decodes filenames (handles spaces and special characters)
- Retrieves file from S3
- Base64-encodes content for JSON transport
- Returns file with proper CORS headers

**Environment Variables**:
- `BUCKET_NAME`: S3 bucket name

### 3. Presign Function (`presign.py`)

**Purpose**: Generates presigned URLs for file sharing

**Key Features**:
- Creates temporary URLs (3600 second expiration)
- No authentication required to access presigned URLs
- Handles both API requests and Cognito triggers
- Returns URL with CORS headers

**Environment Variables**:
- `BUCKET_NAME`: S3 bucket name

### 4. OPTIONS Handler (`options_handler.py`)

**Purpose**: Handles CORS preflight requests

**Key Features**:
- Returns 200 OK with CORS headers
- Allows all origins (*) for development
- Supports GET, POST, OPTIONS methods
- No business logic, pure CORS handling

## Terraform Configuration

### 1. Review Lambda Module Structure

Navigate to `terraform/lambda` and review:

**`main.tf`** - Defines:
- **IAM Role**: Execution role for Lambda functions
- **IAM Policies**: S3 access, CloudWatch Logs
- **Code Packaging**: Automated ZIP creation
- **Function Definitions**: All four Lambda functions
- **Environment Variables**: S3 bucket reference

**`outputs.tf`** - Exports:
- `upload_lambda_arn`: For API Gateway integration
- `download_lambda_arn`: For API Gateway integration
- `presign_lambda_arn`: For API Gateway integration
- `options_lambda_arn`: For CORS handling

**`variables.tf`** - Input variables:
- `bucket_name`: From S3 module
- `bucket_arn`: For IAM permissions
- `cognito_user_pool_id`: For potential use in functions

### 2. Review Lambda Source Code

Navigate to `src/lambda/` and verify all Python scripts:

```bash
ls -la src/lambda/
```

Expected files:
- `upload.py` - Upload handler
- `download.py` - Download handler
- `presign.py` - Presigned URL generator
- `options_handler.py` - CORS handler

### 3. Key Code Patterns

**Base64 Decoding (Upload)**:
```python
body_content = event['body']

# Handle API Gateway base64 encoding
if event.get('isBase64Encoded', False):
    body_content = base64.b64decode(body_content).decode('utf-8')

# Parse JSON
body = json.loads(body_content)
base64_content = body['file_content']

# Decode to binary
file_content = base64.b64decode(base64_content)
```

**URL Decoding (Download)**:
```python
from urllib.parse import unquote

file_key = event['pathParameters']['file_key']
file_key = unquote(file_key)  # "file%20name.pdf" → "file name.pdf"
```

**CORS Headers (All Functions)**:
```python
return {
    'statusCode': 200,
    'headers': {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': '*',
        'Access-Control-Allow-Methods': '*',
        'Content-Type': 'application/json'
    },
    'body': json.dumps({'message': 'Success'})
}
```

## Deployment Steps

### 1. Navigate to Terraform Directory

```bash
cd /Users/voke/Desktop/filesharing/terraform
```

### 2. Verify Main Configuration

Check that `terraform/main.tf` includes:

```hcl
module "lambda" {
  source = "./lambda"
  
  bucket_name         = module.s3.bucket_name
  bucket_arn          = module.s3.bucket_arn
  cognito_user_pool_id = module.cognito.user_pool_id
}
```

### 3. Plan Changes

```bash
terraform plan
```

**Expected Output**:
```
Plan: 8 to add, 0 to change, 0 to destroy.

Resources to be created:
  - aws_iam_role.lambda_execution_role
  - aws_iam_role_policy.lambda_s3_policy
  - aws_iam_role_policy_attachment.lambda_logs
  - aws_lambda_function.upload_function
  - aws_lambda_function.download_function
  - aws_lambda_function.presign_function
  - aws_lambda_function.options_handler_function
  - data.archive_file.lambda_zip (x4)
```

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm.

**Successful Output**:
```
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.

Outputs:
upload_lambda_arn = "arn:aws:lambda:us-east-1:xxx:function:upload_file_function"
download_lambda_arn = "arn:aws:lambda:us-east-1:xxx:function:download_file_function"
presign_lambda_arn = "arn:aws:lambda:us-east-1:xxx:function:presign_url_function"
options_lambda_arn = "arn:aws:lambda:us-east-1:xxx:function:options_handler_function"
```

### 5. Record Lambda ARNs

Save these for API Gateway integration:
```
upload_file_function
download_file_function
presign_url_function
options_handler_function
```

## Testing Lambda Functions

See `tests/test_lambdas.sh` for automated testing script.

### Quick Test Commands

```bash
# Test upload
aws lambda invoke \
  --function-name upload_file_function \
  --payload '{"body":"{\"file_content\":\"'"$(echo -n 'test' | base64)"'\"}","headers":{"file-name":"test.txt"}}' \
  --region us-east-1 \
  /tmp/upload.json

# Test download
aws lambda invoke \
  --function-name download_file_function \
  --payload '{"pathParameters":{"file_key":"test.txt"}}' \
  --region us-east-1 \
  /tmp/download.json

# Test presign
aws lambda invoke \
  --function-name presign_url_function \
  --payload '{"queryStringParameters":{"file_name":"test.txt"}}' \
  --region us-east-1 \
  /tmp/presign.json
```

## Monitoring and Debugging

### View CloudWatch Logs

```bash
# Tail upload function logs
aws logs tail /aws/lambda/upload_file_function --follow --region us-east-1

# Get recent errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/upload_file_function \
  --filter-pattern "ERROR" \
  --region us-east-1
```

### Update Lambda Function Code

```bash
cd /Users/voke/Desktop/filesharing/src/lambda

# Update upload function
zip /tmp/upload.zip upload.py
aws lambda update-function-code \
  --function-name upload_file_function \
  --zip-file fileb:///tmp/upload.zip \
  --region us-east-1
```

## Troubleshooting

### Issue: Lambda Can't Access S3

**Error**: `Access Denied` when accessing S3

**Solution**: Verify IAM role has S3 permissions

### Issue: Timeout Errors

**Error**: Task timed out after 3.00 seconds

**Solution**: Increase Lambda timeout to 30 seconds

### Issue: Environment Variables Not Set

**Error**: `KeyError: 'BUCKET_NAME'`

**Solution**: Verify environment variables in Lambda configuration

## Phase Completion Checklist

- [ ] All four Lambda functions deployed
- [ ] IAM execution role created with S3 permissions
- [ ] Environment variables configured
- [ ] Upload function tested successfully
- [ ] Download function tested successfully
- [ ] Presign function tested successfully
- [ ] OPTIONS handler tested successfully
- [ ] CloudWatch Logs verified
- [ ] Lambda ARNs recorded for API Gateway

## Next Steps

Once Lambda functions are deployed and tested:

➡️ **Proceed to Phase 4: Setup API Gateway** to expose Lambda functions as HTTP endpoints

---

**Phase Status**: ✅ Complete  
**Resources Created**: 4 Lambda Functions, 1 IAM Role, 2 IAM Policies  
**Estimated Time**: 30-45 minutes
