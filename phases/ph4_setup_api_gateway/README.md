# API Gateway and Lambda Setup

This document outlines the steps for setting up the API Gateway and deploying the Lambda functions for the file uploading and sharing system.

## Overview

In this phase, we will configure the API Gateway to handle HTTP requests and integrate it with the Lambda functions that manage file uploads, downloads, and pre-signed URL generation. 

## Steps

1. **Configure API Gateway**
   - Define the API structure, including resources and methods.
   - Set up CORS if necessary for cross-origin requests.
   - Integrate the API methods with the corresponding Lambda functions.

2. **Deploy Lambda Functions**
   - Ensure that the Lambda functions (`upload.py`, `download.py`, `presign.py`) are correctly implemented and tested.
   - Use Terraform to deploy the Lambda functions, ensuring that the necessary IAM roles and permissions are in place.

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