# Lambda Setup

This document outlines the steps for setting up and deploying the Lambda functions for the file uploading and sharing system.

## Prerequisites
- Ensure that you have completed the S3 bucket registration in Phase 1.
- Have AWS CLI configured with the necessary permissions to create lambda resources.

## Steps

2. **Terraform Configuration**
   - Navigate to the `terraform/lambda` directory.
   - Open the `main.tf` file to review the lambda configuration.
   - The configuration includes settings for:
     - IAM Role and Policy (Access Control) 
     - Automated Code Packaging
     - Function Definitions
     - Permissions
   - Open the `output.tf` file to review the output of the S3 bucket that will be  used by other resources as the project goes on
   - The outputs include:
      - presign lambda arn
   - Open the `variables.tf` file to review the variables
      - S3 bucket arn
      - S3 bucket name
      - cognito user pool ID

3. **Scripts**
   - Navigate to the `scripts/` folder and confirm the (`upload.py`, `download.py`, `presign.py`) are correctly written and ready to be deployed
   

3. **Deploy the Lambda Function**
   - Navigate to the `terraform/` folder and confirm from the `main.tf` file that it calls to the lambda module.<br>
    Run the following commands in your terminal:
     ```bash
     terraform init
     terraform fmt
     terraform validate
     terraform plan
     terraform apply
     ```
   - Confirm the action when prompted. This will create the lambda functions and deploy the scripts as defined in the `main.tf` file.


3. **Test API Endpoints**
   - After deployment, test the API endpoints using tools like Postman or curl to ensure they are functioning as expected.
   - Validate that the Lambda functions are triggered correctly and that they interact with S3 as intended.

4. **Monitor and Debug**
   - Set up logging for the Lambda functions to capture any errors or important information.
   - Use AWS CloudWatch to monitor the API Gateway and Lambda performance.

## Checklist

- [ ] Define API Gateway resources and methods in `terraform/api_gateway/main.tf`.
- [ ] Integrate API Gateway with Lambda functions in the Terraform configuration.
- [ ] Deploy Lambda functions using Terraform in `terraform/lambda/main.tf`.
- [ ] Test API endpoints for upload, download, and pre-signed URL generation.
- [ ] Set up logging and monitoring for Lambda functions and API Gateway.

## Next Steps

Once the API Gateway and Lambda functions are set up and tested, we will move on to the integration of these services with the frontend application in the next phase.