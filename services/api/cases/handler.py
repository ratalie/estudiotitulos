import json
import os
import uuid
from datetime import datetime
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['CASES_TABLE']
table = dynamodb.Table(table_name)

def decimal_default(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError

def lambda_handler(event, context):
    """
    Handler para operaciones CRUD de casos
    """
    http_method = event.get('httpMethod', '')
    path_params = event.get('pathParameters') or {}
    body = json.loads(event.get('body', '{}'))
    
    try:
        if http_method == 'POST':
            return create_case(body, event)
        elif http_method == 'GET' and 'case_id' in path_params:
            return get_case(path_params['case_id'])
        elif http_method == 'GET':
            return list_cases(event)
        elif http_method == 'PUT':
            return update_case(path_params['case_id'], body, event)
        else:
            return response(405, {'error': 'Method not allowed'})
    except Exception as e:
        print(f"Error: {str(e)}")
        return response(500, {'error': str(e)})

def create_case(body, event):
    """Crear nuevo caso"""
    case_id = str(uuid.uuid4())
    now = datetime.utcnow().isoformat()
    
    # Extraer usuario del contexto de Cognito
    user_id = event.get('requestContext', {}).get('authorizer', {}).get('claims', {}).get('sub', 'system')
    
    item = {
        'case_id': case_id,
        'scope': body.get('scope', 'basic'),  # basic | dd
        'status': 'created',
        'created_by': user_id,
        'created_at': now,
        'updated_at': now,
        'property_summary': body.get('property_summary', {}),
        'parties_summary': body.get('parties_summary', {}),
        'current_phase': 'F1',
        'metadata': body.get('metadata', {})
    }
    
    table.put_item(Item=item)
    
    # Registrar evento de auditoría
    audit_event(case_id, user_id, 'case_created', item)
    
    return response(201, item)

def get_case(case_id):
    """Obtener caso por ID"""
    result = table.get_item(Key={'case_id': case_id})
    
    if 'Item' not in result:
        return response(404, {'error': 'Case not found'})
    
    return response(200, result['Item'])

def list_cases(event):
    """Listar casos con paginación"""
    query_params = event.get('queryStringParameters') or {}
    limit = int(query_params.get('limit', 20))
    
    scan_kwargs = {'Limit': limit}
    
    if 'last_key' in query_params:
        scan_kwargs['ExclusiveStartKey'] = json.loads(query_params['last_key'])
    
    result = table.scan(**scan_kwargs)
    
    response_body = {
        'items': result.get('Items', []),
        'count': len(result.get('Items', []))
    }
    
    if 'LastEvaluatedKey' in result:
        response_body['last_key'] = json.dumps(result['LastEvaluatedKey'])
    
    return response(200, response_body)

def update_case(case_id, body, event):
    """Actualizar caso"""
    user_id = event.get('requestContext', {}).get('authorizer', {}).get('claims', {}).get('sub', 'system')
    now = datetime.utcnow().isoformat()
    
    update_expr = "SET updated_at = :updated_at, updated_by = :updated_by"
    expr_values = {
        ':updated_at': now,
        ':updated_by': user_id
    }
    
    # Campos actualizables
    updatable_fields = ['status', 'current_phase', 'property_summary', 'parties_summary', 'metadata']
    
    for field in updatable_fields:
        if field in body:
            update_expr += f", {field} = :{field}"
            expr_values[f":{field}"] = body[field]
    
    result = table.update_item(
        Key={'case_id': case_id},
        UpdateExpression=update_expr,
        ExpressionAttributeValues=expr_values,
        ReturnValues='ALL_NEW'
    )
    
    # Registrar evento de auditoría
    audit_event(case_id, user_id, 'case_updated', body)
    
    return response(200, result['Attributes'])

def audit_event(case_id, user_id, action, payload):
    """Registrar evento de auditoría"""
    audit_table = dynamodb.Table(os.environ['AUDIT_TABLE'])
    now = datetime.utcnow().isoformat()
    event_id = str(uuid.uuid4())
    
    audit_table.put_item(Item={
        'case_id': case_id,
        'ts_event_id': f"{now}#{event_id}",
        'actor': user_id,
        'action': action,
        'timestamp': now,
        'payload_redacted': redact_pii(payload)
    })

def redact_pii(data):
    """Redactar PII de los datos"""
    # Implementar lógica de redacción según necesidades
    # Por ahora, solo guardamos estructura sin datos sensibles
    if isinstance(data, dict):
        return {k: '***REDACTED***' if k in ['cedula', 'passport', 'email', 'phone'] else v 
                for k, v in data.items()}
    return data

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
        'body': json.dumps(body, default=decimal_default)
    }
