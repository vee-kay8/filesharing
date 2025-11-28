#!/bin/bash
#
# test_lambdas.sh - Comprehensive test suite for deployed Lambda functions
# Tests: upload, presign, and download flows
#
# Usage:
#   ./tests/test_lambdas.sh
#   AWS_REGION=us-east-1 ./tests/test_lambdas.sh
#   BUCKET_NAME=my-bucket ./tests/test_lambdas.sh
#

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="${BUCKET_NAME:-}" # Will be discovered if empty
UPLOAD_FN="${UPLOAD_FN:-upload_file_function}"
PRESIGN_FN="${PRESIGN_FN:-presign_url_function}"
DOWNLOAD_FN="${DOWNLOAD_FN:-download_file_function}"

TEST_DIR="/tmp/filesharing_test_$$"
TEST_FILE_NAME="test-file-$(date +%s).txt"
TEST_CONTENT="Hello from Lambda test suite - uploaded at $(date)"

# Cleanup on exit
cleanup() {
  if [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}
trap cleanup EXIT

# Helper functions
log_info() {
  echo -e "${GREEN}✓ $1${NC}"
}

log_warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

log_error() {
  echo -e "${RED}✗ $1${NC}"
}

log_section() {
  echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}$1${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check AWS CLI
check_aws_cli() {
  if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install it: https://aws.amazon.com/cli/"
    exit 1
  fi
  log_info "AWS CLI found: $(aws --version)"
}

# Check credentials
check_credentials() {
  if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
    log_error "AWS credentials not configured or invalid"
    exit 1
  fi
  log_info "AWS credentials valid"
}

# Discover or validate bucket name
discover_bucket() {
  if [ -z "$BUCKET_NAME" ]; then
    log_warn "BUCKET_NAME not set, discovering from Lambda environment..."
    BUCKET_NAME=$(aws lambda get-function-configuration \
      --function-name "$PRESIGN_FN" \
      --region "$AWS_REGION" \
      --query "Environment.Variables.BUCKET_NAME" \
      --output text 2>/dev/null || echo "")
    
    if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" = "None" ]; then
      log_error "Could not discover BUCKET_NAME from Lambda. Set it manually: export BUCKET_NAME=your-bucket"
      exit 1
    fi
  fi
  
  # Verify bucket exists
  if ! aws s3 ls "s3://$BUCKET_NAME" --region "$AWS_REGION" &> /dev/null; then
    log_error "Bucket does not exist or is not accessible: s3://$BUCKET_NAME"
    exit 1
  fi
  log_info "Using bucket: s3://$BUCKET_NAME"
}

# Verify Lambda functions exist
verify_lambdas() {
  for fn in "$UPLOAD_FN" "$PRESIGN_FN" "$DOWNLOAD_FN"; do
    if ! aws lambda get-function \
      --function-name "$fn" \
      --region "$AWS_REGION" &> /dev/null; then
      log_error "Lambda function not found: $fn"
      exit 1
    fi
    log_info "Lambda found: $fn"
  done
}

# Test 1: Upload Lambda
test_upload() {
  log_section "TEST 1: Upload Lambda Function"
  
  mkdir -p "$TEST_DIR"
  
  # Create payload
  cat > "$TEST_DIR/upload-payload.json" << EOF
{
  "body": "$TEST_CONTENT",
  "headers": {
    "file-name": "$TEST_FILE_NAME"
  }
}
EOF
  
  log_info "Invoking upload Lambda with file: $TEST_FILE_NAME"
  
  if ! aws lambda invoke \
    --function-name "$UPLOAD_FN" \
    --region "$AWS_REGION" \
    --payload "file://$TEST_DIR/upload-payload.json" \
    "$TEST_DIR/upload-output.json" &> /dev/null; then
    log_error "Failed to invoke upload Lambda"
    exit 1
  fi
  
  # Check response
  STATUS=$(jq -r '.statusCode' "$TEST_DIR/upload-output.json")
  if [ "$STATUS" != "200" ]; then
    log_error "Upload Lambda returned status $STATUS"
    cat "$TEST_DIR/upload-output.json"
    exit 1
  fi
  
  log_info "Upload Lambda returned status 200"
  
  # Verify file in S3
  log_info "Verifying file exists in S3..."
  if ! aws s3 ls "s3://$BUCKET_NAME/$TEST_FILE_NAME" --region "$AWS_REGION" &> /dev/null; then
    log_error "File not found in S3 after upload"
    exit 1
  fi
  
  log_info "File verified in S3: s3://$BUCKET_NAME/$TEST_FILE_NAME"
  
  # Verify content
  DOWNLOADED_CONTENT=$(aws s3 cp "s3://$BUCKET_NAME/$TEST_FILE_NAME" - --region "$AWS_REGION")
  if [ "$DOWNLOADED_CONTENT" != "$TEST_CONTENT" ]; then
    log_error "File content does not match. Expected: '$TEST_CONTENT', Got: '$DOWNLOADED_CONTENT'"
    exit 1
  fi
  
  log_info "File content verified ✓"
}

# Test 2: Presign Lambda
test_presign() {
  log_section "TEST 2: Presign Lambda Function"
  
  # Create payload
  cat > "$TEST_DIR/presign-payload.json" << EOF
{
  "queryStringParameters": {
    "file_name": "$TEST_FILE_NAME"
  }
}
EOF
  
  log_info "Invoking presign Lambda for: $TEST_FILE_NAME"
  
  if ! aws lambda invoke \
    --function-name "$PRESIGN_FN" \
    --region "$AWS_REGION" \
    --payload "file://$TEST_DIR/presign-payload.json" \
    "$TEST_DIR/presign-output.json" &> /dev/null; then
    log_error "Failed to invoke presign Lambda"
    exit 1
  fi
  
  # Check response
  STATUS=$(jq -r '.statusCode' "$TEST_DIR/presign-output.json")
  if [ "$STATUS" != "200" ]; then
    log_error "Presign Lambda returned status $STATUS"
    cat "$TEST_DIR/presign-output.json"
    exit 1
  fi
  
  log_info "Presign Lambda returned status 200"
  
  # Extract presigned URL
  PRESIGNED_URL=$(jq -r '.body | fromjson | .url' "$TEST_DIR/presign-output.json" 2>/dev/null || echo "")
  if [ -z "$PRESIGNED_URL" ] || [ "$PRESIGNED_URL" = "null" ]; then
    log_error "Could not extract presigned URL from response"
    cat "$TEST_DIR/presign-output.json"
    exit 1
  fi
  
  log_info "Presigned URL obtained ✓"
  echo "  URL: ${PRESIGNED_URL:0:80}..."
  
  # Test the presigned URL with curl
  log_info "Testing presigned URL with curl..."
  if ! curl -s -f "$PRESIGNED_URL" -o "$TEST_DIR/presigned-download.txt" &> /dev/null; then
    log_error "Failed to download via presigned URL"
    exit 1
  fi
  
  PRESIGNED_CONTENT=$(cat "$TEST_DIR/presigned-download.txt")
  if [ "$PRESIGNED_CONTENT" != "$TEST_CONTENT" ]; then
    log_error "Downloaded content does not match. Expected: '$TEST_CONTENT', Got: '$PRESIGNED_CONTENT'"
    exit 1
  fi
  
  log_info "Presigned URL download verified ✓"
}

# Test 3: Download Lambda
test_download() {
  log_section "TEST 3: Download Lambda Function"
  
  # Create payload
  cat > "$TEST_DIR/download-payload.json" << EOF
{
  "pathParameters": {
    "file_key": "$TEST_FILE_NAME"
  }
}
EOF
  
  log_info "Invoking download Lambda for: $TEST_FILE_NAME"
  
  if ! aws lambda invoke \
    --function-name "$DOWNLOAD_FN" \
    --region "$AWS_REGION" \
    --payload "file://$TEST_DIR/download-payload.json" \
    "$TEST_DIR/download-output.json" &> /dev/null; then
    log_error "Failed to invoke download Lambda"
    exit 1
  fi
  
  # Check response
  STATUS=$(jq -r '.statusCode' "$TEST_DIR/download-output.json")
  if [ "$STATUS" != "200" ]; then
    log_error "Download Lambda returned status $STATUS"
    cat "$TEST_DIR/download-output.json"
    exit 1
  fi
  
  log_info "Download Lambda returned status 200"
  
  # Extract and decode body
  BODY=$(jq -r '.body' "$TEST_DIR/download-output.json")
  IS_BASE64=$(jq -r '.isBase64Encoded' "$TEST_DIR/download-output.json")
  
  if [ "$IS_BASE64" = "true" ]; then
    DOWNLOAD_CONTENT=$(echo "$BODY" | base64 --decode)
  else
    DOWNLOAD_CONTENT="$BODY"
  fi
  
  if [ "$DOWNLOAD_CONTENT" != "$TEST_CONTENT" ]; then
    log_error "Downloaded content does not match. Expected: '$TEST_CONTENT', Got: '$DOWNLOAD_CONTENT'"
    exit 1
  fi
  
  log_info "Downloaded content verified ✓"
}

# Test 4: Error cases
test_error_cases() {
  log_section "TEST 4: Error Cases"
  
  # Upload with missing file-name header
  log_info "Testing upload with missing file-name header..."
  cat > "$TEST_DIR/upload-bad.json" << EOF
{
  "body": "test",
  "headers": {}
}
EOF
  
  aws lambda invoke \
    --function-name "$UPLOAD_FN" \
    --region "$AWS_REGION" \
    --payload "file://$TEST_DIR/upload-bad.json" \
    "$TEST_DIR/upload-bad-output.json" &> /dev/null
  
  STATUS=$(jq -r '.statusCode' "$TEST_DIR/upload-bad-output.json")
  if [ "$STATUS" = "500" ]; then
    log_info "Upload Lambda correctly returned 500 for missing header ✓"
  else
    log_warn "Expected 500 for missing header, got $STATUS (might be acceptable depending on implementation)"
  fi
  
  # Presign with missing file_name parameter
  log_info "Testing presign with missing file_name parameter..."
  cat > "$TEST_DIR/presign-bad.json" << EOF
{
  "queryStringParameters": {}
}
EOF
  
  aws lambda invoke \
    --function-name "$PRESIGN_FN" \
    --region "$AWS_REGION" \
    --payload "file://$TEST_DIR/presign-bad.json" \
    "$TEST_DIR/presign-bad-output.json" &> /dev/null
  
  STATUS=$(jq -r '.statusCode' "$TEST_DIR/presign-bad-output.json")
  if [ "$STATUS" = "400" ]; then
    log_info "Presign Lambda correctly returned 400 for missing parameter ✓"
  else
    log_warn "Expected 400 for missing parameter, got $STATUS (might be acceptable)"
  fi
  
  # Download non-existent file
  log_info "Testing download of non-existent file..."
  cat > "$TEST_DIR/download-notfound.json" << EOF
{
  "pathParameters": {
    "file_key": "nonexistent-file-xyz-123.txt"
  }
}
EOF
  
  aws lambda invoke \
    --function-name "$DOWNLOAD_FN" \
    --region "$AWS_REGION" \
    --payload "file://$TEST_DIR/download-notfound.json" \
    "$TEST_DIR/download-notfound-output.json" &> /dev/null
  
  STATUS=$(jq -r '.statusCode' "$TEST_DIR/download-notfound-output.json")
  if [ "$STATUS" = "404" ]; then
    log_info "Download Lambda correctly returned 404 for non-existent file ✓"
  else
    log_warn "Expected 404 for non-existent file, got $STATUS (might be acceptable)"
  fi
}

# Cleanup test file from S3
cleanup_s3() {
  log_section "CLEANUP"
  
  log_info "Removing test file from S3..."
  if aws s3 rm "s3://$BUCKET_NAME/$TEST_FILE_NAME" --region "$AWS_REGION" &> /dev/null; then
    log_info "Test file cleaned up ✓"
  else
    log_warn "Could not remove test file (may not exist anymore)"
  fi
}

# Main execution
main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Lambda Function Test Suite"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  check_aws_cli
  check_credentials
  discover_bucket
  verify_lambdas
  
  test_upload
  test_presign
  test_download
  test_error_cases
  cleanup_s3
  
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}✓ All tests passed!${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
