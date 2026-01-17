import json
import os
import uuid
from datetime import datetime
import boto3
import hashlib
import base64

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
textract = boto3.client('textract')

docs_table = dynamodb.Table(os.environ['DOCUMENTS_TABLE'])
raw_bucket = os.environ['RAW_BUCKET']

def lambda_handler(event, context):
    """Handler para gestión de documentos"""
    http_method = event.get('httpMethod', '')
    path_params = event.get('pathParameters') or {}
    
    try:
        if http_method == 'POST':
            return upload_document(event)
        elif http_method == 'GET' and 'doc_id' in path_params:
            return get_document(path_params['doc_id'])
        elif http_method == 'GET':
            return list_documents(event)
        else:
            return response(405, {'error': 'Method not allowed'})
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {'error': str(e)})

def upload_document(event):
    """Subir documento"""
    body = json.loads(event.get('body', '{}'))
    
    case_id = body.get('case_id')
    doc_type = body.get('doc_type')  # escritura, cedula, certificado, etc.
    file_content = body.get('file_content')  # base64 encoded
    file_name = body.get('file_name')
    source = body.get('source', 'upload')
    
    if not all([case_id, doc_type, file_content, file_name]):
        return response(400, {'error': 'Missing required fields'})
    
    # Decodificar contenido
    file_bytes = base64.b64decode(file_content)
    
    # Calcular hash
    file_hash = hashlib.sha256(file_bytes).hexdigest()
    
    # Generar IDs
    doc_id = str(uuid.uuid4())
    now = datetime.utcnow().isoformat()
    user_id = event.get('requestContext', {}).get('authorizer', {}).get('claims', {}).get('sub', 'system')
    
    # Subir a S3
    s3_key = f"{case_id}/{doc_id}/{file_name}"
    s3.put_object(
        Bucket=raw_bucket,
        Key=s3_key,
        Body=file_bytes,
        Metadata={
            'case_id': case_id,
            'doc_id': doc_id,
            'doc_type': doc_type,
            'uploaded_by': user_id,
            'file_hash': file_hash
        }
    )
    
    s3_uri = f"s3://{raw_bucket}/{s3_key}"
    
    # Iniciar Textract si es PDF
    textract_job_id = None
    if file_name.lower().endswith('.pdf'):
        textract_response = textract.start_document_analysis(
            DocumentLocation={
                'S3Object': {
                    'Bucket': raw_bucket,
                    'Name': s3_key
                }
            },
            FeatureTypes=['TABLES', 'FORMS']
        )
        textract_job_id = textract_response['JobId']
    
    # Guardar metadata en DynamoDB
    item = {
        'doc_id': doc_id,
        'case_id': case_id,
        's3_uri': s3_uri,
        's3_bucket': raw_bucket,
        's3_key': s3_key,
        'doc_type': doc_type,
        'file_name': file_name,
        'file_hash': file_hash,
        'source': source,
        'uploaded_by': user_id,
        'uploaded_at': now,
        'textract_job_id': textract_job_id,
        'processed': False,
        'status': 'uploaded'
    }
    
    docs_table.put_item(Item=item)
    
    return response(201, {
        'doc_id': doc_id,
        's3_uri': s3_uri,
        'textract_job_id': textract_job_id,
        'status': 'uploaded'
    })

def get_document(doc_id):
    """Obtener metadata de documento"""
    result = docs_table.get_item(Key={'doc_id': doc_id})
    
    if 'Item' not in result:
        return response(404, {'error': 'Document not found'})
    
    item = result['Item']
    
    # Generar presigned URL para descarga
    presigned_url = s3.generate_presigned_url(
        'get_object',
        Params={
            'Bucket': item['s3_bucket'],
            'Key': item['s3_key']
        },
        ExpiresIn=3600
    )
    
    item['download_url'] = presigned_url
    
    return response(200, item)

def list_documents(event):
    """Listar documentos de un caso"""
    query_params = event.get('queryStringParameters') or {}
    case_id = query_params.get('case_id')
    
    if not case_id:
        return response(400, {'error': 'case_id required'})
    
    # Query usando GSI
    result = docs_table.query(
        IndexName='case_id-index',
        KeyConditionExpression='case_id = :case_id',
        ExpressionAttributeValues={':case_id': case_id}
    )
    
    return response(200, {
        'items': result.get('Items', []),
        'count': len(result.get('Items', []))
    })

def response(status_code, body):
    """Generar respuesta HTTP"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps(body, default=str)
    }
