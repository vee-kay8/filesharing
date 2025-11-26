
# Phase 1: Register S3 Bucket

This document outlines the steps to register an S3 bucket for the file uploading and sharing system.

## Steps to Register S3 Bucket

1. **Prerequisites**
   - Go through the Prerequisite.md file
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
   - Open the `output.tf` file to review the output of the S3 bucket that will be  used by other resources as the project goes on
   - The outputs include:
      - S3 Bucket name
      - S3 Bucket arn

3. **Create the S3 Bucket**
   - Navigate to the `terraform/` folder and confirm from the `main.tf` file that it calls to the s3 module.<br>
    Run the following commands in your terminal:
     ```bash
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

## Next Steps
- Once the S3 bucket is registered, proceed to Phase 2: Setup Cognito for user authentication and authorization.