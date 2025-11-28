# Testing Guide for File Sharing Lambda Functions and Cognito

This directory contains automated test scripts to validate your deployed Lambda functions (upload, presign, download) and Cognito user pool.

## Overview

- **test_lambdas.sh** — Bash script for testing upload, presign, and download Lambda functions
- **test_cognito.sh** — Bash script for testing Cognito user pool and authentication flows
- **test_lambdas_pytest.py** — Python pytest suite for Lambda function tests (with mocking support)

## Prerequisites

### AWS CLI Setup
```bash
aws --version
aws configure  # Set up your credentials and default region
aws sts get-caller-identity  # Verify credentials work
```

### For Bash Scripts
- `jq` (JSON query tool):
  ```bash
  # macOS
  brew install jq
  
  # Ubuntu/Debian
  sudo apt-get install jq
  ```

### For Python Tests
```bash
pip install boto3 pytest
```

## Quick Start

### 1. Test Lambda Functions (Bash)

```bash
cd /Users/voke/Desktop/filesharing

# Make scripts executable
chmod +x tests/test_lambdas.sh
chmod +x tests/test_cognito.sh

# Run with auto-discovery (simplest)
./tests/test_lambdas.sh

# Or specify resources explicitly
export AWS_REGION=us-east-1
export BUCKET_NAME=file-sharing-upload-fstf
./tests/test_lambdas.sh
```

**What it tests:**
- ✓ Upload Lambda: uploads a file to S3
- ✓ Presign Lambda: generates a valid presigned URL
- ✓ Download Lambda: retrieves file content from S3
- ✓ Error cases: missing parameters, non-existent files
- ✓ End-to-end flow: upload → presign → download

**Output example:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Lambda Function Test Suite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ AWS CLI found: aws-cli/2.x.x
✓ AWS credentials valid
✓ Using bucket: s3://file-sharing-upload-fstf
✓ Lambda found: upload_file_function
...
✓ All tests passed!
```

### 2. Test Cognito (Bash)

```bash
# Run with auto-discovery
./tests/test_cognito.sh

# Or specify pool and client
export USER_POOL_ID=us-east-1_xxxxx
export CLIENT_ID=xxxxxxxxxx
./tests/test_cognito.sh
```

**What it tests:**
- ✓ Create user (admin)
- ✓ Set permanent password
- ✓ Authenticate (ADMIN_USER_PASSWORD_AUTH)
- ✓ Get user details
- ✓ MFA configuration (informational)
- ✓ Change password
- ✓ Delete test user (cleanup)

**Output example:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Cognito User Pool Test Suite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
User Pool ID: us-east-1_xxxxx
Client ID: xxxxxxxxxx
Test Email: testuser-1732700000@example.com

✓ User created: testuser@example.com (status: FORCE_CHANGE_PASSWORD)
✓ Permanent password set ✓
✓ Authentication successful ✓
...
✓ All Cognito tests passed!
```

### 3. Test Lambda Functions (Python/pytest)

```bash
# Install pytest if needed
pip install pytest boto3

# Run all tests
cd /Users/voke/Desktop/filesharing
pytest tests/test_lambdas_pytest.py -v

# Run specific test class
pytest tests/test_lambdas_pytest.py::TestUploadLambda -v

# Run with custom config
export BUCKET_NAME=my-bucket
export AWS_REGION=us-west-2
pytest tests/test_lambdas_pytest.py -v -s
```

**Test classes:**
- `TestUploadLambda` — test file upload functionality
- `TestPresignLambda` — test presigned URL generation
- `TestDownloadLambda` — test file download functionality
- `TestEndToEndFlow` — test complete upload → presign → download workflow

## Environment Variables

### For test_lambdas.sh
```bash
AWS_REGION=us-east-1                    # AWS region (default: us-east-1)
BUCKET_NAME=my-bucket                   # S3 bucket name (auto-discovered if empty)
UPLOAD_FN=upload_file_function          # Lambda function name (default: upload_file_function)
PRESIGN_FN=presign_url_function         # Lambda function name (default: presign_url_function)
DOWNLOAD_FN=download_file_function      # Lambda function name (default: download_file_function)
```

### For test_cognito.sh
```bash
AWS_REGION=us-east-1                    # AWS region (default: us-east-1)
USER_POOL_ID=us-east-1_xxxxx            # Cognito user pool ID (auto-discovered if empty)
CLIENT_ID=xxxxxxxxxx                    # Cognito client ID (auto-discovered if empty)
```

### For test_lambdas_pytest.py
```bash
AWS_REGION=us-east-1                    # AWS region (default: us-east-1)
BUCKET_NAME=my-bucket                   # S3 bucket name (auto-discovered if empty)
UPLOAD_FN=upload_file_function          # Lambda function name (default: upload_file_function)
PRESIGN_FN=presign_url_function         # Lambda function name (default: presign_url_function)
DOWNLOAD_FN=download_file_function      # Lambda function name (default: download_file_function)
```

## Troubleshooting

### AWS Credentials Error
```bash
# Check credentials
aws sts get-caller-identity

# Configure if needed
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID=xxxxx
export AWS_SECRET_ACCESS_KEY=xxxxx
export AWS_DEFAULT_REGION=us-east-1
```

### Bucket Not Found Error
```bash
# List available buckets
aws s3 ls

# Set bucket explicitly
export BUCKET_NAME=your-bucket-name
./tests/test_lambdas.sh
```

### Lambda Function Not Found
```bash
# List deployed functions
aws lambda list-functions

# Set function names explicitly
export UPLOAD_FN=your-upload-function-name
export PRESIGN_FN=your-presign-function-name
export DOWNLOAD_FN=your-download-function-name
./tests/test_lambdas.sh
```

### Cognito Pool Not Found
```bash
# List user pools
aws cognito-idp list-user-pools --max-results 60

# Set pool ID explicitly
export USER_POOL_ID=us-east-1_xxxxx
./tests/test_cognito.sh
```

### Permission Errors
Ensure your AWS IAM user has these permissions:
- `lambda:InvokeFunction`
- `lambda:GetFunction`
- `lambda:GetFunctionConfiguration`
- `s3:GetObject`
- `s3:PutObject`
- `s3:DeleteObject`
- `s3:ListBucket`
- `cognito-idp:*` (for Cognito tests)
- `logs:FilterLogEvents` (for CloudWatch log inspection)

### CloudWatch Logs
View Lambda execution logs:
```bash
# List log events for upload Lambda
aws logs filter-log-events \
  --log-group-name "/aws/lambda/upload_file_function" \
  --limit 50 \
  --query "events[].[timestamp,message]" \
  --output text

# View recent errors
aws logs filter-log-events \
  --log-group-name "/aws/lambda/presign_url_function" \
  --filter-pattern "ERROR" \
  --limit 20
```

## CI/CD Integration

### GitHub Actions
```yaml
name: Test Lambdas and Cognito

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq
          pip install boto3 pytest
      
      - name: Test Lambda functions
        run: |
          export BUCKET_NAME=${{ secrets.BUCKET_NAME }}
          chmod +x tests/test_lambdas.sh
          ./tests/test_lambdas.sh
      
      - name: Test Cognito
        run: |
          export USER_POOL_ID=${{ secrets.USER_POOL_ID }}
          export CLIENT_ID=${{ secrets.CLIENT_ID }}
          chmod +x tests/test_cognito.sh
          ./tests/test_cognito.sh
      
      - name: Run pytest
        run: pytest tests/test_lambdas_pytest.py -v
```

### Local Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running Lambda tests..."
./tests/test_lambdas.sh || exit 1

echo "Running Cognito tests..."
./tests/test_cognito.sh || exit 1

echo "All tests passed!"
```

## Manual Testing

If you prefer manual testing, use these AWS CLI commands:

### Upload
```bash
cat > /tmp/upload.json << 'EOF'
{
  "body": "My test content",
  "headers": {
    "file-name": "my-test-file.txt"
  }
}
EOF

aws lambda invoke \
  --function-name upload_file_function \
  --payload file:///tmp/upload.json \
  /tmp/upload-output.json

cat /tmp/upload-output.json
```

### Presign
```bash
cat > /tmp/presign.json << 'EOF'
{
  "queryStringParameters": {
    "file_name": "my-test-file.txt"
  }
}
EOF

aws lambda invoke \
  --function-name presign_url_function \
  --payload file:///tmp/presign.json \
  /tmp/presign-output.json

# Extract and test URL
URL=$(jq -r '.body | fromjson | .url' /tmp/presign-output.json)
curl "$URL" -o /tmp/downloaded-file.txt
cat /tmp/downloaded-file.txt
```

### Download
```bash
cat > /tmp/download.json << 'EOF'
{
  "pathParameters": {
    "file_key": "my-test-file.txt"
  }
}
EOF

aws lambda invoke \
  --function-name download_file_function \
  --payload file:///tmp/download.json \
  /tmp/download-output.json

cat /tmp/download-output.json
```

## Support

For issues or questions:
1. Check CloudWatch logs: `aws logs tail /aws/lambda/YOUR_FUNCTION --follow`
2. Verify IAM permissions for your AWS user
3. Ensure Lambda environment variables are set: `aws lambda get-function-configuration --function-name YOUR_FUNCTION`
4. Check S3 bucket exists and is accessible: `aws s3 ls s3://YOUR_BUCKET`
