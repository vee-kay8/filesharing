
# Phase 1: Register S3 Bucket

This document outlines the steps to register an S3 bucket for the file uploading and sharing system.

## Overview

Amazon S3 (Simple Storage Service) is the foundation of our file sharing system. It provides secure, durable, and scalable object storage for all uploaded files. In this phase, we'll create and configure the S3 bucket using Terraform Infrastructure as Code (IaC).

## Prerequisites

1. **Go through the Prerequisite.md file** in the root directory
2. **AWS CLI installed and configured** with the necessary permissions
   ```bash
   aws --version
   aws configure list
   ```
3. **Terraform installed** on your local machine (version 1.0 or later)
   ```bash
   terraform --version
   ```
4. **AWS Permissions Required:**
   - `s3:CreateBucket`
   - `s3:PutBucketPolicy`
   - `s3:PutBucketVersioning`
   - `s3:PutLifecycleConfiguration`

## Terraform Configuration

### 1. Review S3 Module Structure

Navigate to the `terraform/s3` directory and review the files:

**`main.tf`** - Contains the S3 bucket configuration:
- **Bucket name**: `file-sharing-upload-fstf` (must be globally unique)
- **Versioning**: Enabled for file history and recovery
- **Lifecycle policies**: For cost optimization
- **CORS configuration**: Allows browser-based uploads
- **Permissions**: Bucket policies and ACLs

**`output.tf`** - Defines outputs for use by other modules:
- `bucket_name`: Used by Lambda functions to reference the bucket
- `bucket_arn`: Used for IAM permissions and policies

**`variables.tf`** (if present) - Defines configurable variables

### 2. Review Main Terraform Configuration

Navigate to the root `terraform/` folder and open `main.tf`. Verify it includes:

```hcl
module "s3" {
  source = "./s3"
  # Any required variables
}
```

### 3. Backend Configuration

Check `terraform/backend.tf` for state management. For production, consider using:
- S3 backend for state storage
- DynamoDB for state locking

## Deployment Steps

### 1. Initialize Terraform

```bash
cd /Users/voke/Desktop/filesharing/terraform
terraform init
```

This command:
- Downloads required provider plugins (AWS)
- Initializes the backend
- Sets up the working directory

### 2. Format Configuration Files

```bash
terraform fmt -recursive
```

Ensures consistent formatting across all `.tf` files.

### 3. Validate Configuration

```bash
terraform validate
```

Checks for syntax errors and validates the configuration.

### 4. Review Execution Plan

```bash
terraform plan
```

**Expected Output:**
```
Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bucket_arn  = (known after apply)
  + bucket_name = "file-sharing-upload-fstf"
```

Review the plan carefully to ensure only the S3 bucket will be created.

### 5. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm the action.

**Successful Output:**
```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
bucket_arn = "arn:aws:s3:::file-sharing-upload-fstf"
bucket_name = "file-sharing-upload-fstf"
```

### 6. Note Critical Information

Record the following details for use in subsequent phases:
- **Bucket Name**: `file-sharing-upload-fstf`
- **Bucket ARN**: `arn:aws:s3:::file-sharing-upload-fstf`
- **Region**: `us-east-1`

## Verification

### 1. Verify via AWS Console

1. Log in to [AWS Management Console](https://console.aws.amazon.com/)
2. Navigate to **S3** service
3. Confirm the bucket `file-sharing-upload-fstf` exists
4. Check bucket properties (versioning, CORS, etc.)

### 2. Verify via AWS CLI

```bash
# List buckets
aws s3 ls | grep file-sharing

# Check bucket location
aws s3api get-bucket-location --bucket file-sharing-upload-fstf

# Verify CORS configuration
aws s3api get-bucket-cors --bucket file-sharing-upload-fstf
```

### 3. Test Bucket Access

```bash
# Upload a test file
echo "test" > test.txt
aws s3 cp test.txt s3://file-sharing-upload-fstf/test.txt

# Verify upload
aws s3 ls s3://file-sharing-upload-fstf/

# Clean up test file
aws s3 rm s3://file-sharing-upload-fstf/test.txt
rm test.txt
```

## Troubleshooting

### Issue: Bucket Name Already Exists

**Error:**
```
Error creating S3 bucket: BucketAlreadyExists: The requested bucket name is not available
```

**Solution:**
1. S3 bucket names must be globally unique across all AWS accounts
2. Modify the bucket name in `terraform/s3/main.tf`
3. Choose a name like: `file-sharing-upload-<your-initials>-<random-string>`

### Issue: Insufficient Permissions

**Error:**
```
Error creating S3 bucket: AccessDenied: Access Denied
```

**Solution:**
1. Verify your AWS credentials: `aws sts get-caller-identity`
2. Ensure your IAM user/role has S3 permissions
3. Check AWS CLI configuration: `aws configure list`

### Issue: Terraform State Lock

**Error:**
```
Error acquiring the state lock
```

**Solution:**
1. Check if another Terraform process is running
2. If using DynamoDB backend, verify the lock table
3. Force unlock (use cautiously): `terraform force-unlock <lock-id>`

## Best Practices Implemented

✅ **Infrastructure as Code**: All resources defined in version-controlled Terraform  
✅ **Versioning Enabled**: Protects against accidental deletions and overwrites  
✅ **CORS Configuration**: Enables secure browser-based file uploads  
✅ **Output Variables**: Facilitates resource sharing between modules  
✅ **Consistent Naming**: Following AWS naming conventions

## Security Considerations

🔒 **Bucket Policies**: Restrict public access by default  
🔒 **Encryption**: Consider enabling S3 encryption at rest  
🔒 **Access Logs**: Enable for audit trails (optional for MVP)  
🔒 **Block Public Access**: Ensure all block public access settings are enabled

## Cost Estimation

For MVP/development with low usage:
- **Storage**: ~$0.023 per GB per month (S3 Standard)
- **Requests**: ~$0.005 per 1,000 PUT requests
- **Data Transfer**: Free for first 1GB out per month

**Estimated Monthly Cost**: <$1 for development/testing

## Phase Completion Checklist

- [ ] Terraform initialized successfully
- [ ] S3 bucket created with name `file-sharing-upload-fstf`
- [ ] Bucket verified in AWS Console
- [ ] Bucket ARN and name recorded
- [ ] Test upload/download successful
- [ ] CORS configuration verified
- [ ] Versioning enabled and confirmed

## Next Steps

Once the S3 bucket is successfully registered and verified:

➡️ **Proceed to Phase 2: Setup Cognito** for user authentication and authorization

The S3 bucket ARN and name will be used in Phase 3 when configuring Lambda functions.

---

**Phase Status**: ✅ Complete  
**Resources Created**: 1 S3 Bucket  
**Estimated Time**: 15-20 minutes