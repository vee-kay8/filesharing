# Project Phases Overview

This document provides a high-level overview of all phases involved in building the serverless file sharing application.

## Phase Summary

| Phase | Name | Status | Duration | Key Deliverables |
|-------|------|--------|----------|------------------|
| 1 | S3 Bucket Setup | ✅ Complete | 15-20 min | S3 bucket for file storage |
| 2 | Cognito Setup | ✅ Complete | 20-30 min | User authentication system |
| 3 | Lambda Functions | ✅ Complete | 30-45 min | 4 serverless functions |
| 4 | API Gateway | ✅ Complete | 30-45 min | REST API endpoints |
| 5 | Frontend Development | ✅ Complete | 2-3 hours | React application |
| 6 | Testing & Debugging | ✅ Complete | 4-5 hours | Bug fixes and optimization |

**Total Project Time**: ~8-10 hours

---

## Phase 1: S3 Bucket Setup

**Objective**: Create secure cloud storage for uploaded files

**What You'll Build**:
- S3 bucket with versioning enabled
- CORS configuration for browser uploads
- Bucket policies for access control

**Key Commands**:
```bash
cd terraform
terraform init
terraform apply
```

**Outputs**:
- Bucket Name: `file-sharing-upload-fstf`
- Bucket ARN: For IAM policies

**Prerequisites**: AWS CLI, Terraform installed

[📖 Full Phase 1 Documentation](./ph1_register_s3/README.md)

---

## Phase 2: Cognito Setup

**Objective**: Implement user authentication and authorization

**What You'll Build**:
- Cognito User Pool for user management
- User Pool Client for application integration
- Password policies and email verification
- Test user account

**Key Configuration**:
- Email-based authentication
- Password requirements (8+ chars, uppercase, lowercase, numbers)
- Auth flows: `ALLOW_USER_SRP_AUTH`, `ALLOW_USER_PASSWORD_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH`

**Outputs**:
- User Pool ID: `us-east-1_kirtpO01n`
- Client ID: `71d9sbqv6ghee4qad5p08v2574`

**Prerequisites**: Phase 1 complete

[📖 Full Phase 2 Documentation](./ph2_setup_cognito/README.md)

---

## Phase 3: Lambda Functions

**Objective**: Create serverless business logic

**What You'll Build**:
- **Upload Function**: Handles file uploads with base64 decoding
- **Download Function**: Retrieves files with URL decoding
- **Presign Function**: Generates temporary shareable URLs
- **OPTIONS Handler**: Manages CORS preflight requests

**Key Technologies**:
- Python 3.8
- boto3 for S3 operations
- CloudWatch Logs for monitoring

**Outputs**:
- 4 Lambda function ARNs
- IAM execution role with S3 permissions

**Prerequisites**: Phases 1-2 complete

[📖 Full Phase 3 Documentation](./ph3_setup_lambda/README.md)

---

## Phase 4: API Gateway Setup

**Objective**: Expose Lambda functions as HTTP endpoints

**What You'll Build**:
- REST API with 3 main endpoints
- Cognito authorizer for security
- Lambda proxy integrations
- CORS configuration

**API Endpoints**:
- `POST /upload` - Upload files
- `GET /download/{file_key}` - Download files
- `GET /presign?file_name=...` - Get presigned URL
- `OPTIONS *` - CORS preflight

**Outputs**:
- API Gateway URL: `https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1`
- API Gateway ID: `qopf2wt9g7`

**Prerequisites**: Phases 1-3 complete

[📖 Full Phase 4 Documentation](./ph4_setup_api_gateway/README.md)

---

## Phase 5: Frontend Development

**Objective**: Build user-facing React application

**What You'll Build**:
- React app with AWS Amplify authentication
- FileUpload component with base64 encoding
- FileList component with download/share features
- Responsive CSS styling

**Key Features**:
- Sign up/Sign in with Cognito
- File upload with progress feedback
- File list display
- Download files
- Generate shareable links

**Technologies**:
- React 18
- AWS Amplify v6
- @aws-amplify/ui-react

**Prerequisites**: Phases 1-4 complete, Node.js installed

[📖 Full Phase 5 Documentation](./ph5_frontend_development/README.md)

---

## Phase 6: Testing & Debugging

**Objective**: Identify and fix integration issues

**Challenges Solved**:
1. ✅ CORS preflight failures (500 errors)
2. ✅ File corruption on upload/download
3. ✅ CloudFront caching old responses
4. ✅ JSON parsing errors in Lambda
5. ✅ 404 errors for files with spaces
6. ✅ Missing CORS headers on some endpoints
7. ✅ USER_SRP_AUTH authentication errors
8. ✅ Token fetching issues
9. ✅ React duplicate key warnings

**Testing Coverage**:
- Unit tests for Lambda functions
- Integration tests for API endpoints
- End-to-end user flow testing
- Edge case testing (spaces, special characters)

**Prerequisites**: Phases 1-5 complete

[📖 Full Phase 6 Documentation](./ph6_testing_debugging/README.md)

---

## Quick Start Guide

### For New Developers

1. **Read Prerequisites**: Check `Prerequisite.md` in root directory
2. **Start with Phase 1**: Follow phases sequentially
3. **Test After Each Phase**: Don't skip validation steps
4. **Document Issues**: Keep notes of any problems encountered

### For Debugging

1. **Check CloudWatch Logs**: Most errors show up here
2. **Test with curl**: Isolate backend from frontend issues
3. **Verify CORS**: Many issues are CORS-related
4. **Check Token Validity**: JWT tokens expire after 60 minutes

### For Deployment

1. **Phase 1-4**: Deploy infrastructure with Terraform
2. **Phase 5**: Deploy frontend to Amplify Hosting or S3
3. **Phase 6**: Run all test scripts before production release

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         User Browser                         │
│                    (React Application)                       │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                   AWS Amplify + Cognito                      │
│              (Authentication & Authorization)                │
└────────────────────────┬────────────────────────────────────┘
                         │ JWT Token
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                      API Gateway                             │
│             (REST API + Cognito Authorizer)                  │
│   /upload | /download/{file_key} | /presign                 │
└────────────────────────┬────────────────────────────────────┘
                         │ AWS_PROXY Integration
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                     Lambda Functions                         │
│  upload.py | download.py | presign.py | options_handler.py  │
└────────────────────────┬────────────────────────────────────┘
                         │ boto3 S3 Operations
                         ↓
┌─────────────────────────────────────────────────────────────┐
│                      Amazon S3                               │
│              file-sharing-upload-fstf                        │
│               (File Storage)                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Technologies

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Storage | Amazon S3 | File storage with versioning |
| Auth | Amazon Cognito | User management and JWT tokens |
| Compute | AWS Lambda | Serverless business logic |
| API | API Gateway | REST API and routing |
| Frontend | React + Amplify | User interface |
| IaC | Terraform | Infrastructure management |
| Monitoring | CloudWatch | Logs and metrics |

---

## Success Criteria

### Phase 1-4 (Backend)
- [ ] All Terraform applies successfully
- [ ] Lambda functions deployable via CLI
- [ ] API endpoints return 200 with valid token
- [ ] CORS working on all endpoints
- [ ] Files upload to S3 without corruption

### Phase 5 (Frontend)
- [ ] React app runs on localhost:3000
- [ ] Users can sign up and sign in
- [ ] Files upload successfully
- [ ] Files download without corruption
- [ ] Presigned URLs generate and work

### Phase 6 (Production Ready)
- [ ] All integration tests pass
- [ ] No console errors or warnings
- [ ] Edge cases handled (spaces, special chars)
- [ ] Performance acceptable (<2s upload/download)
- [ ] Security best practices implemented

---

## Common Issues Across Phases

### CORS Problems
**Symptoms**: "Blocked by CORS policy" in browser console  
**Solutions**: 
- Verify OPTIONS returns 200
- Check CORS headers in all Lambda responses
- Wait for CloudFront cache expiration

### Authentication Errors
**Symptoms**: "Unauthorized" or "Invalid token"  
**Solutions**:
- Verify Cognito auth flows include ALLOW_USER_SRP_AUTH
- Check token hasn't expired (60 min lifetime)
- Clear browser localStorage and re-authenticate

### File Corruption
**Symptoms**: Downloaded files can't be opened  
**Solutions**:
- Verify base64 encoding chain: Binary → Base64 → JSON → Base64 → Binary
- Check API Gateway isBase64Encoded flag
- Test with small text files first

---

## Cost Estimation

| Service | Free Tier | Beyond Free Tier | Est. Monthly (MVP) |
|---------|-----------|------------------|-------------------|
| S3 | 5 GB storage | $0.023/GB | $0 |
| Cognito | 50k MAU | $0.0055/MAU | $0 |
| Lambda | 1M requests | $0.20/1M | $0 |
| API Gateway | 1M calls | $3.50/1M | $0 |
| **Total** | | | **$0** |

*All services within free tier for development/MVP*

---

## Additional Resources

- [AWS Documentation](https://docs.aws.amazon.com/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Amplify Docs](https://docs.amplify.aws/)
- [Project Documentation](../PROJECT_DOCUMENTATION.md)
- [Medium Blog Post](../MEDIUM_POST.md)

---

## Support and Troubleshooting

1. **Check Phase-Specific README**: Each phase has detailed troubleshooting
2. **Review CloudWatch Logs**: Most errors visible here
3. **Test Components Individually**: Isolate the problem
4. **Use Testing Scripts**: Automated tests in `tests/` directory

---

**Project Status**: ✅ Production Ready  
**Last Updated**: November 29, 2025  
**Total Lines of Code**: ~2,000  
**Test Coverage**: All critical paths tested
