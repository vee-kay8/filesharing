# Phase 5: Frontend Development

This document outlines the steps for building the React frontend with AWS Amplify authentication.

## Overview

The frontend is a React application that provides a user-friendly interface for:
- User authentication (sign up, sign in, sign out)
- File upload with progress feedback
- File list display
- File download
- Presigned URL generation for file sharing

## Architecture

```
React App (localhost:3000 or deployed)
    ↓
AWS Amplify (Authentication)
    ↓
Cognito User Pool
    ↓ (JWT Token)
API Gateway
    ↓
Lambda Functions → S3
```

## Prerequisites

✅ **Phases 1-4 Complete**: Full backend infrastructure deployed  
✅ **API Gateway URL**: `https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1`  
✅ **Cognito Details**: User Pool ID and Client ID  
✅ **Node.js installed**: Version 14+ recommended  
✅ **npm or yarn**: Package manager

## Technology Stack

- **React**: Frontend framework
- **AWS Amplify v6**: Authentication library
- **@aws-amplify/ui-react**: Pre-built auth components
- **Modern CSS**: Responsive styling

## Project Setup

### 1. Create React App

```bash
cd /Users/voke/Desktop/filesharing
npx create-react-app frontend
cd frontend
```

### 2. Install Dependencies

```bash
npm install aws-amplify @aws-amplify/ui-react
```

**Packages**:
- `aws-amplify`: Core Amplify library
- `@aws-amplify/ui-react`: Pre-built React components (Authenticator)

### 3. Project Structure

```
frontend/
├── public/
│   └── index.html
├── src/
│   ├── components/
│   │   ├── FileUpload.js       # File upload component
│   │   ├── FileUpload.css      # Upload styles
│   │   ├── FileList.js         # File list component
│   │   └── FileList.css        # List styles
│   ├── aws-config.js           # AWS configuration
│   ├── App.js                  # Main app component
│   ├── App.css                 # Main app styles
│   └── index.js                # Entry point
├── package.json
└── README.md
```

## Configuration

### 1. Create AWS Configuration

Create `src/aws-config.js`:

```javascript
const awsConfig = {
  Auth: {
    Cognito: {
      userPoolId: 'us-east-1_kirtpO01n',
      userPoolClientId: '71d9sbqv6ghee4qad5p08v2574',
      loginWith: {
        email: true
      },
      signUpVerificationMethod: 'code',
      userAttributes: {
        email: {
          required: true
        }
      },
      passwordFormat: {
        minLength: 8,
        requireLowercase: true,
        requireUppercase: true,
        requireNumbers: true
      }
    }
  }
};

export const API_ENDPOINT = 'https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1';

export default awsConfig;
```

### 2. Configure Amplify in App.js

```javascript
import { Amplify } from 'aws-amplify';
import { Authenticator } from '@aws-amplify/ui-react';
import awsConfig from './aws-config';
import '@aws-amplify/ui-react/styles.css';

Amplify.configure(awsConfig);
```

## Component Development

### 1. Main App Component (App.js)

**Key Features**:
- Amplify Authenticator wrapper
- User state management
- Automatic token fetching
- Sign out functionality

**Critical Code**:
```javascript
const [user, setUser] = useState(null);
const [idToken, setIdToken] = useState(null);

useEffect(() => {
  if (user && !idToken) {
    fetchIdToken();
  }
}, [user, idToken]);

const fetchIdToken = async () => {
  try {
    const session = await fetchAuthSession({ forceRefresh: true });
    const token = session.tokens?.idToken?.toString();
    setIdToken(token);
  } catch (error) {
    console.error('Failed to fetch token:', error);
  }
};
```

### 2. FileUpload Component

**Key Features**:
- File selection
- Base64 encoding
- Upload to API with JWT token
- Success/error feedback
- localStorage update

**Base64 Encoding**:
```javascript
const handleUpload = async () => {
  const fileContent = await selectedFile.arrayBuffer();
  const base64Content = btoa(
    new Uint8Array(fileContent).reduce(
      (data, byte) => data + String.fromCharCode(byte),
      ''
    )
  );

  const response = await fetch(`${API_ENDPOINT}/upload`, {
    method: 'POST',
    headers: {
      'Authorization': idToken,
      'Content-Type': 'application/json',
      'file-name': selectedFile.name
    },
    body: JSON.stringify({ file_content: base64Content })
  });
};
```

### 3. FileList Component

**Key Features**:
- Reads files from localStorage
- Removes duplicates by filename
- Unique React keys
- Download functionality
- Presigned URL generation

**Deduplication Logic**:
```javascript
const uniqueFiles = uploadedFiles.reduce((acc, file) => {
  const existing = acc.find(f => f.name === file.name);
  if (!existing || new Date(file.uploadedAt) > new Date(existing.uploadedAt)) {
    return [...acc.filter(f => f.name !== file.name), file];
  }
  return acc;
}, []);

const fileObjects = uniqueFiles.map((file) => ({
  id: `${file.name}-${file.uploadedAt}`,  // Unique key
  Key: file.name,
  Size: file.size,
  LastModified: file.uploadedAt
}));
```

## Running the Application

### 1. Start Development Server

```bash
cd /Users/voke/Desktop/filesharing/frontend
npm start
```

The app opens at `http://localhost:3000`

### 2. Sign In

Use test credentials:
- **Email**: `testuser@example.com`
- **Password**: `Password123!`

### 3. Test Features

1. **Upload File**: Select file, click Upload
2. **Download File**: Click download icon
3. **Get Presigned URL**: Click share icon
4. **Sign Out**: Click Sign Out button

## Troubleshooting

### Issue: USER_SRP_AUTH Not Enabled

**Error**: `USER_SRP_AUTH is not enabled for the client`

**Solution**: Already fixed in Phase 2. Verify Cognito auth flows:

```bash
aws cognito-idp describe-user-pool-client \
  --user-pool-id us-east-1_kirtpO01n \
  --client-id 71d9sbqv6ghee4qad5p08v2574 \
  --query 'UserPoolClient.ExplicitAuthFlows'
```

Should return: `ALLOW_USER_SRP_AUTH`, `ALLOW_USER_PASSWORD_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH`

### Issue: CORS Errors

**Error**: `Access to fetch has been blocked by CORS policy`

**Solution**:
1. Verify OPTIONS endpoints return 200
2. Check CORS headers in Lambda responses
3. Clear browser cache
4. Wait for CloudFront cache expiration

### Issue: Authentication Required After Login

**Error**: `Authentication required` after successful login

**Solution**: Already fixed - `forceRefresh: true` in `fetchAuthSession`

### Issue: React Duplicate Key Warnings

**Error**: `Encountered two children with the same key`

**Solution**: Already implemented - unique IDs with `${file.name}-${file.uploadedAt}`

### Issue: Download Returns Corrupted Files

**Error**: Downloaded files can't be opened

**Solution**: Already implemented - proper base64 encoding/decoding chain

## Testing Checklist

- [ ] User can sign up with email/password
- [ ] User can sign in with existing credentials
- [ ] Upload button disabled when no file selected
- [ ] File uploads successfully
- [ ] Success message displayed after upload
- [ ] Uploaded file appears in file list
- [ ] Download works for files without spaces
- [ ] Download works for files with spaces in name
- [ ] Downloaded files open correctly (not corrupted)
- [ ] Presigned URL generation works
- [ ] Presigned URL accessible without authentication
- [ ] Sign out works correctly
- [ ] No console errors or warnings
- [ ] No duplicate key warnings

## Deployment Options

### Option 1: AWS Amplify Hosting

```bash
# Install Amplify CLI
npm install -g @aws-amplify/cli

# Initialize Amplify
amplify init

# Add hosting
amplify add hosting

# Publish
amplify publish
```

### Option 2: S3 + CloudFront

```bash
# Build production version
npm run build

# Create S3 bucket for hosting
aws s3 mb s3://filesharing-frontend

# Upload build files
aws s3 sync build/ s3://filesharing-frontend --acl public-read

# Configure as static website
aws s3 website s3://filesharing-frontend \
  --index-document index.html \
  --error-document index.html
```

### Option 3: Netlify/Vercel

1. Push code to GitHub
2. Connect repository to Netlify/Vercel
3. Configure build command: `npm run build`
4. Configure publish directory: `build`
5. Deploy

## Security Considerations

🔒 **Environment Variables**: Store sensitive config in `.env` files (not in git)  
🔒 **Token Storage**: Amplify handles secure token storage  
🔒 **HTTPS Only**: Use HTTPS in production  
🔒 **Input Validation**: Validate file types and sizes  
🔒 **Error Messages**: Don't expose sensitive information

## Performance Optimization

⚡ **Code Splitting**: Use React lazy loading  
⚡ **Compression**: Enable gzip/brotli  
⚡ **Caching**: Set cache headers  
⚡ **CDN**: Use CloudFront for global distribution  
⚡ **Bundle Size**: Analyze with `npm run build --stats`

## Phase Completion Checklist

- [ ] React app created and running
- [ ] AWS Amplify configured
- [ ] Cognito authentication working
- [ ] FileUpload component functional
- [ ] FileList component displaying files
- [ ] Upload tested with various file types
- [ ] Download tested (with and without spaces)
- [ ] Presigned URLs working
- [ ] No corruption in uploaded/downloaded files
- [ ] CORS working across all endpoints
- [ ] No console warnings or errors
- [ ] Sign out functionality working
- [ ] Responsive design on mobile/desktop

## Next Steps (Optional)

Potential enhancements:

🚀 **Features**:
- Drag-and-drop file upload
- Progress bar for large files
- File preview (images, PDFs)
- Bulk file operations
- Search and filter files
- Folder organization

🔒 **Security**:
- File type validation
- File size limits
- Virus scanning
- Role-based access control

📊 **UX Improvements**:
- Loading indicators
- Better error messages
- Toast notifications
- Confirmation dialogs

---

**Phase Status**: ✅ Complete  
**Resources Created**: React Application with 3 main components  
**Estimated Time**: 2-3 hours
