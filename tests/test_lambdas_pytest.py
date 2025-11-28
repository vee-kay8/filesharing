import os
import json
import boto3
import pytest
from datetime import datetime

# Configuration from environment
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
BUCKET_NAME = os.getenv("BUCKET_NAME", "")
UPLOAD_FN = os.getenv("UPLOAD_FN", "upload_file_function")
PRESIGN_FN = os.getenv("PRESIGN_FN", "presign_url_function")
DOWNLOAD_FN = os.getenv("DOWNLOAD_FN", "download_file_function")

# Initialize clients
lambda_client = boto3.client("lambda", region_name=AWS_REGION)
s3_client = boto3.client("s3", region_name=AWS_REGION)

# Test fixtures
TEST_FILE_NAME = f"test-file-{datetime.now().timestamp()}.txt"
TEST_CONTENT = "Hello from pytest Lambda tests"


@pytest.fixture(scope="session")
def bucket():
    """Discover or use configured bucket name"""
    global BUCKET_NAME
    if not BUCKET_NAME:
        try:
            response = lambda_client.get_function_configuration(
                FunctionName=PRESIGN_FN
            )
            BUCKET_NAME = response.get("Environment", {}).get("Variables", {}).get("BUCKET_NAME")
        except Exception as e:
            pytest.skip(f"Could not discover BUCKET_NAME: {e}")
    
    if not BUCKET_NAME:
        pytest.skip("BUCKET_NAME not configured and could not be discovered")
    
    return BUCKET_NAME


def cleanup_s3_file(bucket_name, file_name):
    """Helper to clean up test files"""
    try:
        s3_client.delete_object(Bucket=bucket_name, Key=file_name)
    except Exception:
        pass


class TestUploadLambda:
    """Tests for the upload Lambda function"""
    
    def test_upload_success(self, bucket):
        """Test successful file upload"""
        payload = {
            "body": TEST_CONTENT,
            "headers": {
                "file-name": TEST_FILE_NAME
            }
        }
        
        response = lambda_client.invoke(
            FunctionName=UPLOAD_FN,
            Payload=json.dumps(payload)
        )
        
        assert response["StatusCode"] == 200
        result = json.loads(response["Payload"].read())
        assert result["statusCode"] == 200
        body = json.loads(result["body"])
        assert "file_name" in body
        assert body["file_name"] == TEST_FILE_NAME
        
        # Verify file in S3
        try:
            s3_response = s3_client.get_object(Bucket=bucket, Key=TEST_FILE_NAME)
            content = s3_response["Body"].read().decode()
            assert content == TEST_CONTENT
        finally:
            cleanup_s3_file(bucket, TEST_FILE_NAME)
    
    def test_upload_missing_file_name(self, bucket):
        """Test upload fails when file-name header is missing"""
        payload = {
            "body": TEST_CONTENT,
            "headers": {}
        }
        
        response = lambda_client.invoke(
            FunctionName=UPLOAD_FN,
            Payload=json.dumps(payload)
        )
        
        assert response["StatusCode"] == 200
        result = json.loads(response["Payload"].read())
        assert result["statusCode"] == 500


class TestPresignLambda:
    """Tests for the presign Lambda function"""
    
    @pytest.fixture(autouse=True)
    def setup_test_file(self, bucket):
        """Create a test file in S3 before each test"""
        s3_client.put_object(
            Bucket=bucket,
            Key=TEST_FILE_NAME,
            Body=TEST_CONTENT.encode()
        )
        yield
        cleanup_s3_file(bucket, TEST_FILE_NAME)
    
    def test_presign_success(self, bucket):
        """Test successful presigned URL generation"""
        payload = {
            "queryStringParameters": {
                "file_name": TEST_FILE_NAME
            }
        }
        
        response = lambda_client.invoke(
            FunctionName=PRESIGN_FN,
            Payload=json.dumps(payload)
        )
        
        assert response["StatusCode"] == 200
        result = json.loads(response["Payload"].read())
        assert result["statusCode"] == 200
        body = json.loads(result["body"])
        assert "url" in body
        assert "s3.amazonaws.com" in body["url"]
    
    def test_presign_missing_file_name(self, bucket):
        """Test presign fails when file_name is missing"""
        payload = {
            "queryStringParameters": {}
        }
        
        response = lambda_client.invoke(
            FunctionName=PRESIGN_FN,
            Payload=json.dumps(payload)
        )
        
        assert response["StatusCode"] == 200
        result = json.loads(response["Payload"].read())
        assert result["statusCode"] == 400


class TestDownloadLambda:
    """Tests for the download Lambda function"""
    
    @pytest.fixture(autouse=True)
    def setup_test_file(self, bucket):
        """Create a test file in S3 before each test"""
        s3_client.put_object(
            Bucket=bucket,
            Key=TEST_FILE_NAME,
            Body=TEST_CONTENT.encode()
        )
        yield
        cleanup_s3_file(bucket, TEST_FILE_NAME)
    
    def test_download_success(self, bucket):
        """Test successful file download"""
        payload = {
            "pathParameters": {
                "file_key": TEST_FILE_NAME
            }
        }
        
        response = lambda_client.invoke(
            FunctionName=DOWNLOAD_FN,
            Payload=json.dumps(payload)
        )
        
        assert response["StatusCode"] == 200
        result = json.loads(response["Payload"].read())
        assert result["statusCode"] == 200
        
        # Decode body if base64 encoded
        body = result["body"]
        is_base64 = result.get("isBase64Encoded", False)
        if is_base64:
            import base64
            body = base64.b64decode(body).decode()
        
        assert body == TEST_CONTENT
    
    def test_download_not_found(self, bucket):
        """Test download fails for non-existent file"""
        payload = {
            "pathParameters": {
                "file_key": "nonexistent-file-xyz.txt"
            }
        }
        
        response = lambda_client.invoke(
            FunctionName=DOWNLOAD_FN,
            Payload=json.dumps(payload)
        )
        
        assert response["StatusCode"] == 200
        result = json.loads(response["Payload"].read())
        assert result["statusCode"] == 404


class TestEndToEndFlow:
    """End-to-end tests combining multiple functions"""
    
    def test_upload_presign_download_flow(self, bucket):
        """Test complete workflow: upload -> presign -> download"""
        # 1. Upload file
        upload_payload = {
            "body": TEST_CONTENT,
            "headers": {
                "file-name": TEST_FILE_NAME
            }
        }
        
        upload_response = lambda_client.invoke(
            FunctionName=UPLOAD_FN,
            Payload=json.dumps(upload_payload)
        )
        
        upload_result = json.loads(upload_response["Payload"].read())
        assert upload_result["statusCode"] == 200
        
        try:
            # 2. Get presigned URL
            presign_payload = {
                "queryStringParameters": {
                    "file_name": TEST_FILE_NAME
                }
            }
            
            presign_response = lambda_client.invoke(
                FunctionName=PRESIGN_FN,
                Payload=json.dumps(presign_payload)
            )
            
            presign_result = json.loads(presign_response["Payload"].read())
            assert presign_result["statusCode"] == 200
            presigned_url = json.loads(presign_result["body"])["url"]
            assert "s3.amazonaws.com" in presigned_url
            
            # 3. Download via Lambda
            download_payload = {
                "pathParameters": {
                    "file_key": TEST_FILE_NAME
                }
            }
            
            download_response = lambda_client.invoke(
                FunctionName=DOWNLOAD_FN,
                Payload=json.dumps(download_payload)
            )
            
            download_result = json.loads(download_response["Payload"].read())
            assert download_result["statusCode"] == 200
            
            # Decode body
            body = download_result["body"]
            is_base64 = download_result.get("isBase64Encoded", False)
            if is_base64:
                import base64
                body = base64.b64decode(body).decode()
            
            assert body == TEST_CONTENT
        
        finally:
            cleanup_s3_file(bucket, TEST_FILE_NAME)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
