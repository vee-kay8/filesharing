# Phase 4: Setup API Gateway

This document outlines the steps for setting up API Gateway to expose Lambda functions as HTTP endpoints.

## Overview

Amazon API Gateway creates a RESTful API that serves as the HTTP interface for our serverless application. It handles:
- HTTP request routing to Lambda functions
- Authentication via Cognito authorizer
- CORS configuration for browser access
- Request/response transformation
- Rate limiting and throttling

## Architecture

```
Client (Browser/Mobile)
    ↓ HTTPS
API Gateway (REST API)
    ↓ (Cognito Authorizer validates JWT)
Lambda Functions
    ↓
S3 Bucket
```

## Prerequisites

✅ **Phase 1-3 Complete**: S3, Cognito, and Lambda functions deployed  
✅ **Lambda ARNs recorded** from Phase 3  
✅ **Cognito User Pool ARN** from Phase 2  
✅ **AWS CLI configured** with API Gateway permissions

## API Endpoints

### 1. POST /upload
- **Purpose**: Upload files to S3
- **Authentication**: Required (Cognito JWT)
- **Headers**: `Authorization`, `file-name`
- **Body**: JSON with base64-encoded file content
- **Response**: Success/error message

### 2. GET /download/{file_key}
- **Purpose**: Download files from S3
- **Authentication**: Required (Cognito JWT)
- **Path Parameter**: `file_key` - Name of file to download
- **Response**: Base64-encoded file content

### 3. GET /presign
- **Purpose**: Generate presigned URL for file sharing
- **Authentication**: Required (Cognito JWT)
- **Query Parameter**: `file_name` - Name of file
- **Response**: Presigned URL (valid for 1 hour)

### 4. OPTIONS (all endpoints)
- **Purpose**: Handle CORS preflight requests
- **Authentication**: None
- **Response**: CORS headers

## Terraform Configuration

### 1. Review API Gateway Module

Navigate to `terraform/api_gateway` and review `main.tf`:

**Key Components**:
- **REST API**: Main API container
- **Resources**: `/upload`, `/download/{file_key}`, `/presign`
- **Methods**: POST, GET, OPTIONS
- **Integrations**: Lambda proxy integrations
- **Authorizer**: Cognito User Pool authorizer
- **Deployment**: API deployment to stage

### 2. Verify Main Terraform Configuration

Ensure `terraform/main.tf` includes:

```hcl
module "api_gateway" {
  source = "./api_gateway"
  
  upload_lambda_arn   = module.lambda.upload_lambda_arn
  download_lambda_arn = module.lambda.download_lambda_arn
  presign_lambda_arn  = module.lambda.presign_lambda_arn
  options_lambda_arn  = module.lambda.options_lambda_arn
  user_pool_arn       = module.cognito.user_pool_arn
}
```

## Deployment Steps

### 1. Navigate to Terraform Directory

```bash
cd /Users/voke/Desktop/filesharing/terraform
```

### 2. Plan Changes

```bash
terraform plan
```

**Expected Output**:
```
Plan: 15+ resources to add

Resources include:
  - aws_api_gateway_rest_api
  - aws_api_gateway_resource (x3)
  - aws_api_gateway_method (x8)
  - aws_api_gateway_integration (x8)
  - aws_api_gateway_authorizer
  - aws_api_gateway_deployment
  - aws_api_gateway_stage
  - aws_lambda_permission (x4)
```

### 3. Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm.

**Successful Output**:
```
Apply complete! Resources: 15+ added

Outputs:
api_gateway_url = "https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1"
api_gateway_id = "qopf2wt9g7"
```

### 4. Record API Information

**Critical Information**:
```
API Gateway ID: qopf2wt9g7
API Endpoint: https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1
Stage: v1
Region: us-east-1
```

## Testing API Gateway

### 1. Test OPTIONS Endpoint (CORS)

```bash
curl -I -X OPTIONS "https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1/upload"
```

**Expected Response**:
```
HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: *
Access-Control-Allow-Methods: *
```

### 2. Get Authentication Token

```bash
# Login to get JWT token
TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id 71d9sbqv6ghee4qad5p08v2574 \
  --auth-parameters USERNAME=testuser@example.com,PASSWORD=Password123! \
  --region us-east-1 \
  --query 'AuthenticationResult.IdToken' \
  --output text)

echo "Token: $TOKEN"
```

### 3. Test Upload Endpoint

```bash
# Create test file
echo "Hello from API Gateway!" > test.txt
BASE64_CONTENT=$(base64 < test.txt | tr -d '\n')

# Upload via API
curl -X POST \
  "https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1/upload" \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -H "file-name: test.txt" \
  -d "{\"file_content\": \"$BASE64_CONTENT\"}"
```

**Expected Response**:
```json
{
  "message": "File uploaded successfully",
  "file_name": "test.txt"
}
```

### 4. Test Download Endpoint

```bash
curl -X GET \
  "https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1/download/test.txt" \
  -H "Authorization: $TOKEN"
```

### 5. Test Presign Endpoint

```bash
curl -X GET \
  "https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1/presign?file_name=test.txt" \
  -H "Authorization: $TOKEN"
```

**Expected Response**:
```json
{
  "presigned_url": "https://file-sharing-upload-fstf.s3.amazonaws.com/test.txt?..."
}
```

## Automated Testing Script

See `tests/test_cognito.sh` for API testing with authentication.

## Troubleshooting

### Issue: 403 Forbidden - Unauthorized

**Error**: `{"message":"Unauthorized"}`

**Cause**: Missing or invalid JWT token

**Solution**:
1. Verify token is included in Authorization header
2. Check token hasn't expired (valid for 60 minutes)
3. Ensure USER_SRP_AUTH is enabled in Cognito
4. Get fresh token if expired

### Issue: 500 Internal Server Error

**Error**: API returns 500 status

**Cause**: Lambda function error

**Solution**:
1. Check CloudWatch Logs for Lambda function
2. Verify Lambda has correct IAM permissions
3. Test Lambda directly (bypass API Gateway)

```bash
aws logs tail /aws/lambda/upload_file_function --follow --region us-east-1
```

### Issue: CORS Errors in Browser

**Error**: `Access to fetch blocked by CORS policy`

**Cause**: Missing or incorrect CORS headers

**Solution**:
1. Verify OPTIONS method returns 200 OK
2. Check CORS headers are present in responses
3. Clear CloudFront cache if using CDN
4. Wait 10-15 seconds for cache expiration

```bash
# Test OPTIONS with cache-busting
curl -I -X OPTIONS "https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1/upload?nocache=$(date +%s)"
```

### Issue: Path Parameters Not Working

**Error**: 404 for download with spaces in filename

**Cause**: Spaces not URL-encoded

**Solution**:
Ensure filenames are URL-encoded in requests:
```javascript
const encodedFilename = encodeURIComponent(filename);
fetch(`${API_URL}/download/${encodedFilename}`);
```

Lambda handles decoding automatically with `urllib.parse.unquote`.

## CloudWatch Monitoring

### Set Up Logging

API Gateway logs are automatically sent to CloudWatch:

```bash
# View API Gateway logs
aws logs tail /aws/apigateway/FileShareAPI --follow --region us-east-1
```

### Key Metrics to Monitor

- **4xx Errors**: Client errors (authentication, validation)
- **5xx Errors**: Server errors (Lambda failures)
- **Latency**: Response time
- **Request Count**: Traffic volume

## API Gateway Configuration Details

### Cognito Authorizer

```hcl
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "CognitoAuthorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  provider_arns = [var.user_pool_arn]
}
```

### Lambda Integration (AWS_PROXY)

```hcl
resource "aws_api_gateway_integration" "upload" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_post.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.upload_lambda_arn
}
```

**AWS_PROXY Benefits**:
- Passes entire request to Lambda
- Lambda returns full HTTP response
- Supports all HTTP features
- Easier debugging

## Security Best Practices

🔒 **Authentication**: All endpoints except OPTIONS require Cognito JWT  
🔒 **HTTPS Only**: API Gateway enforces HTTPS  
🔒 **Rate Limiting**: Configure throttling (default: 10,000 requests/second)  
🔒 **Input Validation**: Lambda functions validate all inputs  
🔒 **CORS Restrictions**: Consider restricting origins in production

## Cost Estimation

API Gateway Pricing (as of 2025):
- **Free Tier**: 1 million API calls per month
- **Beyond Free Tier**: $3.50 per million calls

**Estimated Monthly Cost for MVP**: $0 (within free tier)

## Integration with Frontend (Phase 5)

The API endpoint will be used in the React frontend:

```javascript
const API_ENDPOINT = "https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1";

// Upload file
await fetch(`${API_ENDPOINT}/upload`, {
  method: 'POST',
  headers: {
    'Authorization': idToken,
    'Content-Type': 'application/json',
    'file-name': filename
  },
  body: JSON.stringify({ file_content: base64Content })
});
```

## Phase Completion Checklist

- [ ] API Gateway REST API created
- [ ] All endpoints configured (upload, download, presign)
- [ ] OPTIONS methods working (CORS)
- [ ] Cognito authorizer attached
- [ ] Lambda integrations configured
- [ ] API deployed to v1 stage
- [ ] Upload endpoint tested with auth
- [ ] Download endpoint tested
- [ ] Presign endpoint tested
- [ ] API endpoint URL recorded

## Next Steps

Once API Gateway is deployed and tested:

➡️ **Proceed to Phase 5: Build React Frontend** to create user interface

API endpoint URL will be used in frontend configuration.

---

**Phase Status**: ✅ Complete  
**Resources Created**: REST API, 3 Resources, 8 Methods, 1 Authorizer, 1 Deployment  
**Estimated Time**: 30-45 minutes
