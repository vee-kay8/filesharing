import boto3
import json
import os # Import os module

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Retrieve bucket name from environment variable
    bucket_name = os.environ.get('BUCKET_NAME')
    
    if not bucket_name:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Bucket name environment variable is missing'})
        }
        
    # Assuming API Gateway path parameter
    try:
        file_key = event['pathParameters']['file_key']
    except KeyError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing file_key path parameter'})
        }

    try:
        # Retrieve the file from S3
        response = s3.get_object(Bucket=bucket_name, Key=file_key)
        file_content = response['Body'].read()

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/octet-stream',
                'Content-Disposition': f'attachment; filename="{file_key}"'
            },
            'body': file_content.decode('latin-1'), # Decode binary for JSON/API Gateway
            'isBase64Encoded': True
        }
    except s3.exceptions.NoSuchKey:
        return {
            'statusCode': 404,
            'body': json.dumps({'error': 'File not found'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }