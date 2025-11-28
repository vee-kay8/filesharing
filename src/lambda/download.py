import boto3
import json
import os
import base64
from urllib.parse import unquote

s3 = boto3.client('s3')

def lambda_handler(event, context):
    print(f"Event: {json.dumps(event)}")
    
    # Retrieve bucket name from environment variable
    bucket_name = os.environ.get('BUCKET_NAME')
    
    if not bucket_name:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': '*'
            },
            'body': json.dumps({'error': 'Bucket name environment variable is missing'})
        }
        
    # Assuming API Gateway path parameter
    try:
        file_key = event['pathParameters']['file_key']
        # URL decode the file key (handles spaces and special characters)
        file_key = unquote(file_key)
        print(f"File key (decoded): {file_key}")
    except KeyError:
        return {
            'statusCode': 400,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': '*'
            },
            'body': json.dumps({'error': 'Missing file_key path parameter'})
        }

    try:
        # Retrieve the file from S3
        print(f"Attempting to download from bucket: {bucket_name}, key: {file_key}")
        response = s3.get_object(Bucket=bucket_name, Key=file_key)
        file_content = response['Body'].read()
        print(f"Successfully retrieved file, size: {len(file_content)} bytes")

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': '*',
                'Content-Type': 'application/octet-stream',
                'Content-Disposition': f'attachment; filename="{file_key}"'
            },
            'body': base64.b64encode(file_content).decode('utf-8'),
            'isBase64Encoded': True
        }
    except s3.exceptions.NoSuchKey:
        print(f"File not found: {file_key}")
        return {
            'statusCode': 404,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': '*'
            },
            'body': json.dumps({'error': 'File not found'})
        }
    except Exception as e:
        print(f"Error downloading file: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': '*'
            },
            'body': json.dumps({'error': str(e)})
        }