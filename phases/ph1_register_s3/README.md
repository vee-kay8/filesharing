
# Phase 1: Register S3 Bucket

This document outlines the steps to register an S3 bucket for the file uploading and sharing system.

## Steps to Register S3 Bucket

1. **Prerequisites**
   - Ensure you have the AWS CLI installed and configured with the necessary permissions.
   - Install Terraform on your local machine.

2. **Terraform Configuration**
   - Navigate to the `terraform/s3` directory.
   - Open the `main.tf` file to review the S3 bucket configuration.
   - The configuration includes settings for:
     - Bucket name
     - Versioning
     - Lifecycle policies
     - Permissions

3. **Create the S3 Bucket**
   - Run the following commands in your terminal:
     ```bash
     cd terraform/s3
     terraform init
     terraform fmt
     terraform validate
     terraform plan
     terraform apply
     ```
   - Confirm the action when prompted. This will create the S3 bucket as defined in the `main.tf` file.

4. **Note the Bucket Name**
   - After the successful creation of the bucket, take note of the bucket name as it will be required in subsequent phases.

5. **Post-Setup Actions**
   - Verify the bucket creation in the AWS Management Console.
   - Set up any necessary bucket policies or permissions based on your application requirements.

## Next Steps
- Once the S3 bucket is registered, proceed to Phase 2: Setup Cognito for user authentication and authorization.