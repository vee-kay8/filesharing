#!/bin/bash
#
# test_cognito.sh - Test Cognito user pool and authentication flows
#
# Usage:
#   ./tests/test_cognito.sh
#   AWS_REGION=us-east-1 USER_POOL_ID=us-east-1_xxxxx CLIENT_ID=xxxxx ./tests/test_cognito.sh
#

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
USER_POOL_ID="${USER_POOL_ID:-}"
CLIENT_ID="${CLIENT_ID:-}"
TEST_EMAIL="testuser-$(date +%s)@example.com"
TEST_PASSWORD="TestPass123!"

TEST_DIR="/tmp/filesharing_cognito_test_$$"

# Cleanup
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

log_header() {
  echo -e "${BLUE}$1${NC}"
}

# Check AWS CLI
check_aws_cli() {
  if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found"
    exit 1
  fi
  log_info "AWS CLI found"
}

# Check credentials
check_credentials() {
  if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
    log_error "AWS credentials not configured"
    exit 1
  fi
  log_info "AWS credentials valid"
}

# Discover user pool and client
discover_pool_and_client() {
  if [ -z "$USER_POOL_ID" ]; then
    log_warn "USER_POOL_ID not set, discovering..."
    USER_POOL_ID=$(aws cognito-idp list-user-pools \
      --max-results 60 \
      --region "$AWS_REGION" \
      --query "UserPools[0].Id" \
      --output text 2>/dev/null || echo "")
    
    if [ -z "$USER_POOL_ID" ] || [ "$USER_POOL_ID" = "None" ]; then
      log_error "Could not discover USER_POOL_ID. Set it manually: export USER_POOL_ID=us-east-1_xxxxx"
      exit 1
    fi
    log_info "Discovered user pool: $USER_POOL_ID"
  fi
  
  # Verify pool exists
  if ! aws cognito-idp describe-user-pool \
    --user-pool-id "$USER_POOL_ID" \
    --region "$AWS_REGION" &> /dev/null; then
    log_error "User pool not found: $USER_POOL_ID"
    exit 1
  fi
  
  if [ -z "$CLIENT_ID" ]; then
    log_warn "CLIENT_ID not set, discovering..."
    CLIENT_ID=$(aws cognito-idp list-user-pool-clients \
      --user-pool-id "$USER_POOL_ID" \
      --region "$AWS_REGION" \
      --query "UserPoolClients[0].ClientId" \
      --output text 2>/dev/null || echo "")
    
    if [ -z "$CLIENT_ID" ] || [ "$CLIENT_ID" = "None" ]; then
      log_error "Could not discover CLIENT_ID. Set it manually: export CLIENT_ID=xxxxx"
      exit 1
    fi
    log_info "Discovered client: $CLIENT_ID"
  fi
  
  # Verify client exists
  if ! aws cognito-idp describe-user-pool-client \
    --user-pool-id "$USER_POOL_ID" \
    --client-id "$CLIENT_ID" \
    --region "$AWS_REGION" &> /dev/null; then
    log_error "Client not found: $CLIENT_ID"
    exit 1
  fi
}

# Test 1: Admin create user
test_admin_create_user() {
  log_section "TEST 1: Admin Create User"
  
  mkdir -p "$TEST_DIR"
  
  log_info "Creating test user: $TEST_EMAIL"
  
  if ! aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$TEST_EMAIL" \
    --user-attributes Name=email,Value="$TEST_EMAIL" \
    --temporary-password "$TEST_PASSWORD" \
    --message-action SUPPRESS \
    --region "$AWS_REGION" \
    > "$TEST_DIR/create-user.json" 2>&1; then
    log_error "Failed to create user"
    cat "$TEST_DIR/create-user.json"
    exit 1
  fi
  
  USERNAME=$(jq -r '.User.Username' "$TEST_DIR/create-user.json")
  USER_STATUS=$(jq -r '.User.UserStatus' "$TEST_DIR/create-user.json")
  
  log_info "User created: $USERNAME (status: $USER_STATUS)"
}

# Test 2: Set permanent password
test_set_permanent_password() {
  log_section "TEST 2: Set Permanent Password"
  
  log_info "Setting permanent password for: $TEST_EMAIL"
  
  if ! aws cognito-idp admin-set-user-password \
    --user-pool-id "$USER_POOL_ID" \
    --username "$TEST_EMAIL" \
    --password "$TEST_PASSWORD" \
    --permanent \
    --region "$AWS_REGION" &> /dev/null; then
    log_error "Failed to set permanent password"
    exit 1
  fi
  
  log_info "Permanent password set ✓"
}

# Test 3: Admin initiate auth (password auth)
test_admin_initiate_auth() {
  log_section "TEST 3: Admin Initiate Auth (PASSWORD flow)"
  
  log_info "Authenticating as: $TEST_EMAIL"
  
  if ! aws cognito-idp admin-initiate-auth \
    --user-pool-id "$USER_POOL_ID" \
    --client-id "$CLIENT_ID" \
    --auth-flow ADMIN_USER_PASSWORD_AUTH \
    --auth-parameters "USERNAME=$TEST_EMAIL,PASSWORD=$TEST_PASSWORD" \
    --region "$AWS_REGION" \
    > "$TEST_DIR/auth-result.json" 2>&1; then
    log_error "Authentication failed"
    cat "$TEST_DIR/auth-result.json"
    exit 1
  fi
  
  # Check for tokens
  ID_TOKEN=$(jq -r '.AuthenticationResult.IdToken // empty' "$TEST_DIR/auth-result.json")
  ACCESS_TOKEN=$(jq -r '.AuthenticationResult.AccessToken // empty' "$TEST_DIR/auth-result.json")
  REFRESH_TOKEN=$(jq -r '.AuthenticationResult.RefreshToken // empty' "$TEST_DIR/auth-result.json")
  
  if [ -z "$ID_TOKEN" ] || [ -z "$ACCESS_TOKEN" ]; then
    log_error "Authentication succeeded but no tokens returned"
    cat "$TEST_DIR/auth-result.json"
    exit 1
  fi
  
  log_info "Authentication successful ✓"
  log_header "  IdToken: ${ID_TOKEN:0:50}..."
  log_header "  AccessToken: ${ACCESS_TOKEN:0:50}..."
  log_header "  RefreshToken: ${REFRESH_TOKEN:0:50}..."
}

# Test 4: Get user details
test_get_user() {
  log_section "TEST 4: Get User Details"
  
  log_info "Fetching user details: $TEST_EMAIL"
  
  if ! aws cognito-idp admin-get-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$TEST_EMAIL" \
    --region "$AWS_REGION" \
    > "$TEST_DIR/user-details.json" 2>&1; then
    log_error "Failed to get user details"
    exit 1
  fi
  
  EMAIL=$(jq -r '.UserAttributes[] | select(.Name=="email") | .Value' "$TEST_DIR/user-details.json")
  STATUS=$(jq -r '.UserStatus' "$TEST_DIR/user-details.json")
  ENABLED=$(jq -r '.Enabled' "$TEST_DIR/user-details.json")
  
  log_info "User email: $EMAIL"
  log_info "User status: $STATUS"
  log_info "User enabled: $ENABLED"
}

# Test 5: Test MFA setup (optional)
test_mfa_options() {
  log_section "TEST 5: MFA Configuration (informational)"
  
  log_info "Checking MFA options..."
  
  aws cognito-idp admin-get-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$TEST_EMAIL" \
    --region "$AWS_REGION" \
    --query "UserMFASettingList" \
    --output json > "$TEST_DIR/mfa-settings.json"
  
  MFA_COUNT=$(jq 'length' "$TEST_DIR/mfa-settings.json")
  if [ "$MFA_COUNT" -gt 0 ]; then
    log_info "MFA is enabled for this user"
    jq '.' "$TEST_DIR/mfa-settings.json"
  else
    log_info "No MFA settings for this user"
  fi
}

# Test 6: Change password
test_change_password() {
  log_section "TEST 6: Change Password"
  
  NEW_PASSWORD="NewPass123!"
  
  # Get access token from previous auth
  ACCESS_TOKEN=$(jq -r '.AuthenticationResult.AccessToken' "$TEST_DIR/auth-result.json")
  
  log_info "Changing password for: $TEST_EMAIL"
  
  if ! aws cognito-idp change-password \
    --previous-password "$TEST_PASSWORD" \
    --proposed-password "$NEW_PASSWORD" \
    --access-token "$ACCESS_TOKEN" \
    --region "$AWS_REGION" &> /dev/null; then
    log_error "Failed to change password"
    exit 1
  fi
  
  log_info "Password changed ✓"
  
  # Test login with new password
  log_info "Testing login with new password..."
  
  if ! aws cognito-idp admin-initiate-auth \
    --user-pool-id "$USER_POOL_ID" \
    --client-id "$CLIENT_ID" \
    --auth-flow ADMIN_USER_PASSWORD_AUTH \
    --auth-parameters "USERNAME=$TEST_EMAIL,PASSWORD=$NEW_PASSWORD" \
    --region "$AWS_REGION" \
    > "$TEST_DIR/auth-new-password.json" 2>&1; then
    log_error "Login with new password failed"
    exit 1
  fi
  
  log_info "Login with new password successful ✓"
}

# Test 7: Delete user (cleanup)
test_delete_user() {
  log_section "TEST 7: Cleanup - Delete Test User"
  
  log_info "Deleting test user: $TEST_EMAIL"
  
  if ! aws cognito-idp admin-delete-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$TEST_EMAIL" \
    --region "$AWS_REGION" &> /dev/null; then
    log_error "Failed to delete user (may already be deleted or may require MFA)"
    return 1
  fi
  
  log_info "Test user deleted ✓"
}

# Main execution
main() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Cognito User Pool Test Suite"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  check_aws_cli
  check_credentials
  discover_pool_and_client
  
  log_header "\nUser Pool ID: $USER_POOL_ID"
  log_header "Client ID: $CLIENT_ID"
  log_header "Test Email: $TEST_EMAIL"
  
  test_admin_create_user
  test_set_permanent_password
  test_admin_initiate_auth
  test_get_user
  test_mfa_options
  test_change_password
  test_delete_user
  
  echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}✓ All Cognito tests passed!${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main "$@"
