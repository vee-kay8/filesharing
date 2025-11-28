import json
import boto3
import base64
import os

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    try:
        print(f"Event: {json.dumps(event)}")
        bucket_name = os.environ['BUCKET_NAME']
        
        # Get file name from headers (case-insensitive)
        headers = {k.lower(): v for k, v in event.get('headers', {}).items()}
        file_name = headers.get('file-name')
        
        if not file_name:
            raise ValueError("Missing file-name header")
        
        # Check if body is base64 encoded (from API Gateway)
        body_content = event['body']
        if event.get('isBase64Encoded', False):
            body_content = base64.b64decode(body_content).decode('utf-8')
        
        # Parse the JSON body to get base64 content
        body = json.loads(body_content)
        base64_content = body['file_content']
        
        if not base64_content:
            raise ValueError("Missing file_content in body")
        
        # Decode base64 to binary
        file_content = base64.b64decode(base64_content)

        # Upload the file to S3
        s3_client.put_object(Bucket=bucket_name, Key=file_name, Body=file_content)
        
        print(f"Successfully uploaded {file_name} to {bucket_name}")

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': '*'
            },
            'body': json.dumps({'message': 'File uploaded successfully', 'file_name': file_name})
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': '*',
                'Content-Type': 'application/json'
            },
            'body': json.dumps({'error': str(e)})
        }