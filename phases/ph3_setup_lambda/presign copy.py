import boto3
import os
import json # Ensure json is imported

def generate_presigned_url(bucket_name, object_key, expiration=3600):
    s3_client = boto3.client('s3')
    try:
        response = s3_client.generate_presigned_url('get_object',
            Params={'Bucket': bucket_name, 'Key': object_key},
            ExpiresIn=expiration
        )
    except Exception as e:
        print(f"Error generating presigned URL: {e}")
        return None

    return response

def lambda_handler(event, context):
    
    # -------------------------------------------------------------
    # 🎯 NEW CHECK: If invoked by Cognito Pre-Sign Up Trigger
    # Cognito trigger events always contain 'triggerSource'
    if 'triggerSource' in event and event['triggerSource'] == 'PreSignUp_AdminCreateUser':
        # Cognito expects the *original event* data back to confirm
        # the trigger executed successfully.
        # If you wanted to auto-confirm the user, you could add:
        # event['response']['autoConfirmUser'] = True
        # event['response']['autoVerifyEmail'] = True
        return event
    
    # -------------------------------------------------------------
    # ORIGINAL LOGIC: If invoked by API Gateway (for presigning)
    
    bucket_name = os.environ.get('BUCKET_NAME') 
    
    if not bucket_name:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Bucket name environment variable is missing'})
        }
        
    # Safely get object_key from query string parameters
    object_key = event.get('queryStringParameters', {}).get('file_name')

    if not object_key:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'file_name query parameter is required'})
        }

    presigned_url = generate_presigned_url(bucket_name, object_key)

    if presigned_url is None:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Could not generate presigned URL'})
        }

    return {
        'statusCode': 200,
        'body': json.dumps({'url': presigned_url})
    }