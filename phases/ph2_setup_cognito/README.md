# Phase 2: Setup AWS Cognito

This document outlines the steps and considerations for setting up AWS Cognito as part of the file uploading and sharing system.

## Overview

Amazon Cognito provides user authentication and authorization for our file sharing application. It handles user registration, login, token management, and integrates seamlessly with API Gateway to secure our endpoints.

## Architecture

```
User Browser → Cognito User Pool → JWT Token → API Gateway Authorizer → Lambda Functions
```

Cognito will:
- Manage user sign-up and sign-in
- Issue JWT tokens for authentication
- Enforce password policies
- Provide user profile management

## Prerequisites

✅ **Phase 1 Complete**: S3 bucket created and verified  
✅ **AWS CLI configured** with permissions for Cognito resources  
✅ **Required IAM Permissions**:
   - `cognito-idp:CreateUserPool`
   - `cognito-idp:CreateUserPoolClient`
   - `cognito-idp:CreateUserPoolDomain` (optional)
   - `cognito-idp:AdminCreateUser`

## Terraform Configuration

### 1. Review Cognito Module Structure

Navigate to `terraform/cognito` and review:

**`main.tf`** - Defines:
- **User Pool**: Manages user directory
- **User Pool Client**: Application integration settings
- **Password Policy**: Security requirements
- **Authentication Flows**: Allowed auth methods

**`outputs.tf`** - Exports:
- `user_pool_id`: For API Gateway authorizer
- `user_pool_client_id`: For frontend configuration
- `user_pool_arn`: For IAM policies

**`variables.tf`** - Configurable parameters

### 2. Key Configuration Settings

Review these critical settings in `terraform/cognito/main.tf`:

```hcl
resource "aws_cognito_user_pool" "user_pool" {
  name = "FileShareUserPool"
  
  # Email-based authentication
  username_attributes = ["email"]
  
  # Password policy
  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }
  
  # Auto-verify email
  auto_verified_attributes = ["email"]
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "FileShareClient"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  
  # CRITICAL: Auth flows for AWS Amplify
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",      # Secure Remote Password
    "ALLOW_USER_PASSWORD_AUTH", # Username/Password
    "ALLOW_REFRESH_TOKEN_AUTH"  # Token refresh
  ]
  
  # Token validity
  id_token_validity      = 60  # minutes
  access_token_validity  = 60  # minutes
  refresh_token_validity = 30  # days
}
```

### 3. Verify Main Terraform Configuration

Ensure `terraform/main.tf` includes:

```hcl
module "cognito" {
  source = "./cognito"
}

# Use outputs in other modules
module "api_gateway" {
  source         = "./api_gateway"
  user_pool_arn  = module.cognito.user_pool_arn
  # ... other variables
}
```

## Deployment Steps

### 1. Navigate to Terraform Directory

```bash
cd /Users/voke/Desktop/filesharing/terraform
```

### 2. Initialize (if not already done)

```bash
terraform init
```

### 3. Plan Changes

```bash
terraform plan
```

**Expected Output:**
```
Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + user_pool_arn       = (known after apply)
  + user_pool_client_id = (known after apply)
  + user_pool_id        = (known after apply)
```

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm.

**Successful Output:**
```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:
user_pool_arn = "arn:aws:cognito-idp:us-east-1:xxxx:userpool/us-east-1_kirtpO01n"
user_pool_client_id = "71d9sbqv6ghee4qad5p08v2574"
user_pool_id = "us-east-1_kirtpO01n"
```

### 5. Record Critical Information

**Save these values** - you'll need them for API Gateway and frontend:

```
User Pool ID: us-east-1_kirtpO01n
User Pool Client ID: 71d9sbqv6ghee4qad5p08v2574
User Pool ARN: arn:aws:cognito-idp:us-east-1:xxxx:userpool/us-east-1_kirtpO01n
Region: us-east-1
```

## Post-Deployment Configuration

### 1. Create Test User

```bash
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_kirtpO01n \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com Name=email_verified,Value=true \
  --temporary-password TempPassword123! \
  --message-action SUPPRESS \
  --region us-east-1
```

### 2. Set Permanent Password

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id us-east-1_kirtpO01n \
  --username testuser@example.com \
  --password Password123! \
  --permanent \
  --region us-east-1
```

### 3. Verify User Creation

```bash
aws cognito-idp admin-get-user \
  --user-pool-id us-east-1_kirtpO01n \
  --username testuser@example.com \
  --region us-east-1
```

## Verification

### 1. Verify via AWS Console

1. Navigate to **Amazon Cognito** in AWS Console
2. Select **User Pools**
3. Find `FileShareUserPool`
4. Check:
   - **Users and groups**: Verify test user exists
   - **App clients**: Confirm client settings
   - **App integration**: Review configuration

### 2. Test Authentication Flow

```bash
# Initiate authentication
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id 71d9sbqv6ghee4qad5p08v2574 \
  --auth-parameters USERNAME=testuser@example.com,PASSWORD=Password123! \
  --region us-east-1
```

**Expected Response:**
```json
{
    "AuthenticationResult": {
        "AccessToken": "eyJraWQiOiJ...",
        "IdToken": "eyJraWQiOiJxc2...",
        "RefreshToken": "eyJjdHkiOiJ...",
        "TokenType": "Bearer",
        "ExpiresIn": 3600
    }
}
```

### 3. Verify Token

Extract the `IdToken` from above and decode it at [jwt.io](https://jwt.io) to verify claims.

## Testing Script

Create `phases/ph2_setup_cognito/test_cognito.sh`:

```bash
#!/bin/bash

USER_POOL_ID="us-east-1_kirtpO01n"
CLIENT_ID="71d9sbqv6ghee4qad5p08v2574"
USERNAME="testuser@example.com"
PASSWORD="Password123!"
REGION="us-east-1"

echo "Testing Cognito Authentication..."

# Test login
RESPONSE=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=$USERNAME,PASSWORD=$PASSWORD \
  --region $REGION 2>&1)

if echo "$RESPONSE" | grep -q "IdToken"; then
    echo "✅ Authentication successful!"
    echo "IdToken received and can be used for API calls"
else
    echo "❌ Authentication failed!"
    echo "$RESPONSE"
    exit 1
fi
```

Run it:
```bash
chmod +x phases/ph2_setup_cognito/test_cognito.sh
./phases/ph2_setup_cognito/test_cognito.sh
```

## Troubleshooting

### Issue: USER_SRP_AUTH Not Enabled

**Error:**
```
USER_SRP_AUTH is not enabled for the client
```

**Solution:**
Ensure `explicit_auth_flows` includes `ALLOW_USER_SRP_AUTH`:

```bash
aws cognito-idp update-user-pool-client \
  --user-pool-id us-east-1_kirtpO01n \
  --client-id 71d9sbqv6ghee4qad5p08v2574 \
  --explicit-auth-flows ALLOW_USER_SRP_AUTH ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --region us-east-1
```

### Issue: Password Policy Violation

**Error:**
```
Password did not conform with policy: Password must have uppercase characters
```

**Solution:**
Ensure passwords meet requirements:
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number

### Issue: User Already Exists

**Error:**
```
An account with the given email already exists
```

**Solution:**
Either delete the existing user or use a different email:

```bash
aws cognito-idp admin-delete-user \
  --user-pool-id us-east-1_kirtpO01n \
  --username testuser@example.com \
  --region us-east-1
```

## Authentication Flow Explained

### 1. User Registration/Login
```
User → Enters credentials → Cognito User Pool
```

### 2. Token Issuance
```
Cognito → Validates credentials → Issues JWT tokens
- ID Token (identity claims)
- Access Token (API authorization)
- Refresh Token (get new tokens)
```

### 3. API Authentication
```
User → Includes ID Token in request → API Gateway
API Gateway → Validates token with Cognito → Allows/Denies
```

## Important Configuration Notes

### Auth Flows Required for AWS Amplify

When using AWS Amplify on the frontend, you **MUST** enable:
- `ALLOW_USER_SRP_AUTH` - Secure Remote Password authentication
- `ALLOW_USER_PASSWORD_AUTH` - Username/password authentication
- `ALLOW_REFRESH_TOKEN_AUTH` - Token refresh capability

Missing `ALLOW_USER_SRP_AUTH` will cause authentication failures with Amplify.

### Token Validity Settings

Consider your application's security requirements:
- **Short-lived tokens** (1 hour): More secure, requires frequent refresh
- **Longer tokens** (24 hours): Better UX, less secure
- **Refresh tokens** (30 days): Balance between security and convenience

## Security Best Practices

🔒 **Password Policy**: Enforce strong passwords  
🔒 **Email Verification**: Auto-verify email addresses  
🔒 **MFA (Optional)**: Add multi-factor authentication for production  
🔒 **Account Recovery**: Configure password reset flow  
🔒 **User Attributes**: Only collect necessary information  
🔒 **Token Expiration**: Use short-lived access tokens

## Cost Estimation

Amazon Cognito Pricing (as of 2025):
- **Free Tier**: 50,000 MAU (Monthly Active Users)
- **Beyond Free Tier**: $0.0055 per MAU

**Estimated Monthly Cost for MVP**: $0 (within free tier)

## Integration with Other Phases

### Used in Phase 4 (API Gateway)

```hcl
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "CognitoAuthorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  provider_arns = [var.user_pool_arn]  # From Cognito module
}
```

### Used in Phase 5 (Frontend)

```javascript
import { Amplify } from 'aws-amplify';

Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: 'us-east-1_kirtpO01n',      // From Cognito
      userPoolClientId: '71d9sbqv6ghee4qad5p08v2574'  // From Cognito
    }
  }
});
```

## Phase Completion Checklist

- [ ] User Pool created successfully
- [ ] User Pool Client configured with correct auth flows
- [ ] Test user created and verified
- [ ] Authentication tested via AWS CLI
- [ ] JWT tokens successfully generated
- [ ] User Pool ID and Client ID recorded
- [ ] Password policy meets security requirements
- [ ] Email verification configured

## Next Steps

Once Cognito is successfully configured and tested:

➡️ **Proceed to Phase 3: Setup Lambda Functions** for file operations

The Cognito User Pool ARN will be used in Phase 4 to secure API Gateway endpoints.

---

**Phase Status**: ✅ Complete  
**Resources Created**: 1 User Pool, 1 User Pool Client  
**Estimated Time**: 20-30 minutes