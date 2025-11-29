# Building a Serverless File Sharing App with AWS: A Journey Through Challenges and Solutions

*How I built a production-ready file sharing application using AWS Lambda, API Gateway, S3, and React — and the interesting problems I encountered along the way.*

---

## Introduction

Have you ever wondered what it takes to build a secure, serverless file sharing application from scratch? I recently embarked on this journey, and while the destination was rewarding, the path was filled with fascinating challenges that taught me invaluable lessons about AWS services, CORS, base64 encoding, and React development.

In this article, I'll walk you through building a complete file sharing application that allows users to:
- 🔐 Securely authenticate using Amazon Cognito
- 📤 Upload files to the cloud
- 📥 Download their files anytime
- 🔗 Generate shareable presigned URLs

More importantly, I'll share the real-world problems I encountered and how I solved them — because let's be honest, that's where the real learning happens.

---

## The Tech Stack

Before diving in, here's what I used:

**Backend:**
- AWS Lambda (Python 3.8) for serverless compute
- Amazon API Gateway for RESTful API
- Amazon S3 for file storage
- Amazon Cognito for user authentication
- Terraform for infrastructure as code

**Frontend:**
- React with Create React App
- AWS Amplify for authentication
- Modern CSS for styling

The beauty of this stack? No servers to manage, automatic scaling, and pay-per-use pricing. Perfect for a side project or MVP.

---

## Phase 1: Setting Up the Infrastructure

### Starting with Terraform

I decided to use Terraform to manage my infrastructure because, well, clicking through the AWS console gets old fast. My Terraform setup included:

```hcl
# S3 bucket for file storage
resource "aws_s3_bucket" "file_bucket" {
  bucket = "file-sharing-upload-fstf"
}

# Cognito User Pool for authentication
resource "aws_cognito_user_pool" "user_pool" {
  name = "FileShareUserPool"
  
  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
  }
}

# Lambda functions for business logic
resource "aws_lambda_function" "upload_function" {
  filename      = "lambda_upload.zip"
  function_name = "upload_file_function"
  runtime       = "python3.8"
  handler       = "upload.lambda_handler"
  # ... more configuration
}
```

The initial setup was straightforward. I created:
1. An S3 bucket for storing files
2. A Cognito User Pool for managing users
3. Three Lambda functions (upload, download, presign)
4. An API Gateway to expose these functions as HTTP endpoints

Everything deployed successfully on the first try, and I felt pretty good about myself. Little did I know...

---

## Phase 2: Building the React Frontend

With the backend ready, I jumped into building the frontend. I wanted something clean and user-friendly:

```javascript
import { Authenticator } from '@aws-amplify/ui-react';
import { Amplify } from 'aws-amplify';

// Configure Amplify
Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: 'us-east-1_kirtpO01n',
      userPoolClientId: '71d9sbqv6ghee4qad5p08v2574',
    }
  }
});

function App() {
  return (
    <Authenticator>
      {({ signOut, user }) => (
        <div className="app-container">
          <FileUpload />
          <FileList />
        </div>
      )}
    </Authenticator>
  );
}
```

I created three main components:
- **App.js**: Main container with Amplify Authenticator
- **FileUpload.js**: Handles file selection and upload
- **FileList.js**: Displays uploaded files with download/share options

Ran `npm start`, and boom — a beautiful login page appeared. I created a test user, signed in, and... that's when the fun began.

---

## The Challenges: Where Theory Meets Reality

### Challenge #1: The Mysterious CORS Beast 🐉

**The Problem:**
I clicked "Upload" and immediately saw this in the console:

```
Access to fetch at 'https://...' from origin 'http://localhost:3000' 
has been blocked by CORS policy: Response to preflight request doesn't 
pass access control check: It does not have HTTP ok status.
```

My OPTIONS requests were returning 500 errors instead of 200. Nothing worked from the browser, though my CLI tests worked fine.

**The Investigation:**
I initially set up MOCK integrations for OPTIONS methods in API Gateway, following some online tutorials. These were supposed to return CORS headers automatically. Spoiler alert: they didn't work reliably.

After diving into CloudWatch Logs (my new best friend), I discovered the MOCK integrations were failing intermittently. Sometimes they worked, sometimes they didn't. Not great for production.

**The Solution:**
I created a dedicated Lambda function to handle CORS:

```python
def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': '*',
            'Access-Control-Allow-Methods': '*',
            'Access-Control-Allow-Credentials': 'true'
        },
        'body': json.dumps({'message': 'CORS OK'})
    }
```

Then I updated my Terraform to use AWS_PROXY integration instead of MOCK:

```hcl
resource "aws_api_gateway_method" "upload_options" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.upload.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_options" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.upload.id
  http_method = aws_api_gateway_method.upload_options.http_method
  
  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = aws_lambda_function.options_handler.invoke_arn
}
```

**Lesson Learned:** Lambda-based CORS handling is more reliable than MOCK integrations. Plus, you get proper logging and error handling.

---

### Challenge #2: The Case of the Corrupted PDFs 📄❌

**The Problem:**
Upload worked! The file appeared in S3! I felt victorious... until I tried to open the downloaded file. The PDF was corrupted. Text files were garbled. Images were broken.

**The Investigation:**
I spent an embarrassing amount of time thinking S3 was corrupting my files (sorry, AWS team). Then I realized: the file size in S3 was different from the original. The upload or download was mangling the data.

After adding extensive logging, I discovered I was sending binary data directly in the request body. When API Gateway received it, things got messy with encoding issues.

**The Solution:**
I implemented proper base64 encoding in the frontend:

```javascript
const handleUpload = async () => {
  const fileContent = await selectedFile.arrayBuffer();
  
  // Convert to base64
  const base64Content = btoa(
    new Uint8Array(fileContent).reduce(
      (data, byte) => data + String.fromCharCode(byte),
      ''
    )
  );

  // Send as JSON
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

And updated the Lambda to decode it:

```python
def lambda_handler(event, context):
    # Parse JSON body
    body = json.loads(event['body'])
    base64_content = body['file_content']
    
    # Decode base64 to binary
    file_content = base64.b64decode(base64_content)
    
    # Upload to S3
    s3_client.put_object(
        Bucket=bucket_name,
        Key=file_name,
        Body=file_content
    )
```

**Lesson Learned:** When dealing with binary data through JSON APIs, base64 encoding is your friend. Always encode on the way in, decode on the way out.

---

### Challenge #3: CloudFront's Cache Conspiracy 🎭

**The Problem:**
After fixing CORS, it worked... sometimes. I'd test, it would fail. Wait 30 seconds, test again, it would succeed. Was my code possessed?

**The Investigation:**
I ran the same curl command multiple times:

```bash
# First attempt
curl -I -X OPTIONS "https://api-id.execute-api.us-east-1.amazonaws.com/v1/upload"
HTTP/1.1 500 Internal Server Error  # 😢

# 30 seconds later
curl -I -X OPTIONS "https://api-id.execute-api.us-east-1.amazonaws.com/v1/upload"
HTTP/1.1 200 OK  # 🎉
```

Then it hit me: CloudFront was caching my old, broken 500 responses!

**The Solution:**
I added cache-busting query parameters to my tests:

```bash
curl -I -X OPTIONS "https://api-id.amazonaws.com/v1/upload?nocache=$(date +%s)"
```

For the application, I just had to wait for the CloudFront TTL to expire (about 10-15 seconds). Future improvement: configure CloudFront to not cache error responses.

**Lesson Learned:** When debugging API Gateway with CloudFront, remember that cache exists. Use query parameters or wait for TTL expiration.

---

### Challenge #4: The JSON Parsing Mystery 🔍

**The Problem:**
Upload returned a response, but my frontend got this error:

```javascript
Unexpected token < in JSON at position 0
// or
Expecting value: line 1 column 1 (char 0)
```

**The Investigation:**
I added logging to see what API Gateway was sending to my Lambda:

```python
print(f"Event: {json.dumps(event)}")
print(f"Body type: {type(event['body'])}")
```

The logs revealed something surprising:

```json
{
  "body": "eyJmaWxlX2NvbnRlbnQiOiAiSkVKVU5rWnZj...",
  "isBase64Encoded": true
}
```

API Gateway was base64-encoding my already-JSON body! 

**The Solution:**
I added a check for base64 encoding before parsing:

```python
def lambda_handler(event, context):
    body_content = event['body']
    
    # Check if API Gateway base64-encoded the body
    if event.get('isBase64Encoded', False):
        body_content = base64.b64decode(body_content).decode('utf-8')
    
    # Now parse as JSON
    body = json.loads(body_content)
    base64_content = body['file_content']
    
    # Rest of the code...
```

**Lesson Learned:** API Gateway might base64-encode request bodies depending on the content type and size. Always check the `isBase64Encoded` flag.

---

### Challenge #5: The Spaces Odyssey 🚀

**The Problem:**
Files without spaces in their names downloaded fine:
- ✅ `document.pdf` — Works!
- ✅ `image.png` — Works!
- ❌ `Solution Architect RBC.pdf` — 404 Not Found

**The Investigation:**
I logged the incoming file_key in the download Lambda:

```python
file_key = event['pathParameters']['file_key']
print(f"Requested file: {file_key}")
```

CloudWatch showed: `Solution%20Architect%20RBC.pdf`

But in S3, the file was stored as: `Solution Architect RBC.pdf`

The mismatch! API Gateway URL-encodes path parameters, but I wasn't decoding them.

**The Solution:**
One import fixed everything:

```python
from urllib.parse import unquote

def lambda_handler(event, context):
    file_key = event['pathParameters']['file_key']
    file_key = unquote(file_key)  # Decode URL encoding
    
    # Now S3 lookup works!
    response = s3_client.get_object(Bucket=bucket_name, Key=file_key)
```

**Lesson Learned:** Always decode URL-encoded path parameters before using them. Spaces become `%20`, and other special characters get encoded too.

---

### Challenge #6: The Authentication Saga 🎭

**The Problem:**
New users couldn't sign in. The error message:

```
USER_SRP_AUTH is not enabled for the client.
```

**The Investigation:**
I checked my Cognito User Pool Client configuration and found that `explicit_auth_flows` was missing the required flow for AWS Amplify.

**The Solution:**
I updated the Terraform configuration:

```hcl
resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "FileShareClient"
  user_pool_id = aws_cognito_user_pool.user_pool.id
  
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",      # Required for Amplify!
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}
```

Because Terraform's state was out of sync, I applied it directly with AWS CLI:

```bash
aws cognito-idp update-user-pool-client \
  --user-pool-id us-east-1_kirtpO01n \
  --client-id 71d9sbqv6ghee4qad5p08v2574 \
  --explicit-auth-flows ALLOW_USER_SRP_AUTH \
                        ALLOW_USER_PASSWORD_AUTH \
                        ALLOW_REFRESH_TOKEN_AUTH
```

But wait, there's more! After enabling SRP auth, users still got "Authentication required" errors. The session tokens weren't being fetched automatically.

I fixed this in React by adding proper state management:

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
    console.error('Token fetch failed:', error);
  }
};
```

**Lesson Learned:** AWS Amplify requires specific Cognito auth flows. Always check compatibility between your frontend framework and backend configuration.

---

## The Final Architecture

After solving all these challenges, here's what the final system looks like:

```
User Browser
    ↓
React App (AWS Amplify)
    ↓
API Gateway (REST API)
    ↓
Cognito Authorizer
    ↓
Lambda Functions
    ↓
S3 Bucket
```

**The User Flow:**
1. User signs in via Cognito (Amplify UI)
2. Selects a file and clicks Upload
3. Frontend converts file to base64, wraps in JSON
4. API Gateway validates JWT token with Cognito
5. Upload Lambda decodes base64, uploads to S3
6. User can download files or generate presigned URLs
7. Download Lambda retrieves from S3, encodes to base64
8. Frontend decodes and presents file to user

---

## Key Takeaways

### 1. **CORS is a Journey, Not a Destination**
Don't rely on API Gateway MOCK integrations for production. Lambda-based CORS handlers give you better control, logging, and reliability.

### 2. **Base64 is Your Binary Best Friend**
When sending binary data through JSON APIs:
- Frontend: Convert to base64 before sending
- Backend: Decode base64 before storing
- Download: Encode to base64 before sending back
- Frontend: Decode before presenting

### 3. **CloudFront Caching is Real**
Always consider caching when debugging API issues. What you see might be a cached response, not the current reality.

### 4. **API Gateway Transforms Data**
Watch out for:
- `isBase64Encoded` flag in requests
- URL encoding in path parameters
- Header key case-insensitivity

### 5. **Amplify + Cognito Marriage**
These two are meant to work together, but you need to configure Cognito with the right auth flows. `ALLOW_USER_SRP_AUTH` is crucial.

### 6. **Logging Saves Lives**
I cannot stress this enough. Add detailed logging everywhere:
```python
print(f"Event: {json.dumps(event)}")
print(f"File key: {file_key}")
print(f"Is base64: {event.get('isBase64Encoded')}")
```

### 7. **Terraform State Can Drift**
Sometimes AWS CLI is faster than fighting with Terraform state. Just remember to update your Terraform files to match.

---

## What's Next?

The application works beautifully now, but there's always room for improvement:

🚀 **Future Enhancements:**
- Implement server-side file listing (instead of localStorage)
- Add file deletion functionality
- Support for drag-and-drop uploads
- File sharing with specific users
- Expiration dates for presigned URLs
- File preview for images and PDFs
- Progress bars for large file uploads

🔒 **Security Improvements:**
- Restrict CORS to specific origins
- Add rate limiting
- Implement virus scanning
- Add CloudWatch alarms
- Enable AWS WAF

---

## Conclusion

Building this serverless file sharing application was an incredible learning experience. Yes, I encountered challenges — from CORS headaches to base64 encoding mysteries — but each problem taught me something valuable about AWS services and web development.

The serverless approach means:
- ✅ No servers to patch or maintain
- ✅ Automatic scaling from 0 to millions of users
- ✅ Pay only for what you use
- ✅ Built-in security with Cognito

If you're thinking about building something similar, I encourage you to dive in. The challenges you'll face will teach you more than any tutorial ever could.

---

## Resources

**Code Repository:** [GitHub Link]

**Key Documentation:**
- [AWS Lambda with Python](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [API Gateway CORS](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-cors.html)
- [AWS Amplify Auth](https://docs.amplify.aws/react/build-a-backend/auth/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

**Useful Commands:**
```bash
# Tail Lambda logs in real-time
aws logs tail /aws/lambda/function-name --follow

# Test CORS with curl
curl -I -X OPTIONS "https://your-api.amazonaws.com/endpoint"

# Update Cognito client
aws cognito-idp update-user-pool-client --user-pool-id <id> --client-id <id>
```

---

**Have you built something similar? Encountered different challenges?** Drop a comment below — I'd love to hear about your experiences!

**Found this helpful?** Give it a clap 👏 and follow for more real-world AWS and serverless content.

---

*Happy building! May your CORS be ever in your favor.* 🚀

---

**About the Author**

I'm a developer passionate about serverless architectures and AWS services. I believe the best way to learn is by building real projects and sharing the lessons learned along the way. Follow me for more practical tutorials and real-world problem-solving!

---

**Tags:** #AWS #Serverless #Lambda #React #WebDevelopment #CloudComputing #APIGateway #S3 #Cognito #Terraform #FileSharing #Tutorial
