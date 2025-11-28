import boto3
import os
import json 
from datetime import datetime # No longer strictly needed but okay to keep

def generate_presigned_url(bucket_name, object_key, expiration=3600):
    s3_client = boto3.client('s3')
    try:
        response = s3_client.generate_presigned_url('get_object',
            Params={'Bucket': bucket_name, 'Key': object_key},
            ExpiresIn=expiration
        )
    except Exception as e:
        # Log the error for debugging
        print(f"Error generating presigned URL for key {object_key}: {e}")
        return None

    return response

def lambda_handler(event, context):
    
    # -------------------------------------------------------------
    # 🎯 Cognito Trigger Check (Pre-Sign Up)
    if 'triggerSource' in event and event['triggerSource'].startswith('PreSignUp_'):
        # This is the required pass-through response for Cognito triggers
        return event
    
    # -------------------------------------------------------------
    # API Gateway / Client Invocation Logic

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
        
    # Retrieve file_name safely from query string parameters
    # The keys in `queryStringParameters` are case-sensitive
    object_key = event.get('queryStringParameters', {}).get('file_name')

    if not object_key:
        return {
            'statusCode': 400,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': '*'
            },
            'body': json.dumps({'error': 'file_name query parameter is required'})
        }

    presigned_url = generate_presigned_url(bucket_name, object_key)

    if presigned_url is None:
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*',
                'Access-Control-Allow-Methods': '*'
            },
            'body': json.dumps({'error': 'Could not generate presigned URL'})
        }
    
    # Return a JSON object containing the URL
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': '*',
            'Access-Control-Allow-Methods': '*',
            'Content-Type': 'application/json'
        },
        'body': json.dumps({'url': presigned_url})
    }