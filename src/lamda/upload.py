import json
import boto3
import os

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    try:
        bucket_name = os.environ['BUCKET_NAME']
        file_content = event['body']
        file_name = event['headers']['file-name']

        # Upload the file to S3
        s3_client.put_object(Bucket=bucket_name, Key=file_name, Body=file_content)

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'File uploaded successfully', 'file_name': file_name})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }