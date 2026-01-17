"""
Tools para Bedrock Agent - Gestión de casos
"""
import json
import os
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
cases_table = dynamodb.Table(os.environ['CASES_TABLE'])
findings_table = dynamodb.Table(os.environ['FINDINGS_TABLE'])
gates_table = dynamodb.Table(os.environ['GATES_TABLE'])

def lambda_handler(event, context):
    """
    Router para tools del agente
    """
    action = event.get('actionGroup', '')
    api_path = event.get('apiPath', '')
    parameters = event.get('parameters', [])
    
    # Convertir parameters array a dict
    params = {p['name']: p['value'] for p in parameters}
    
    try:
        if api_path == '/case/create':
            result = create_case_tool(params)
        elif api_path == '/case/get':
            result = get_case_tool(params)
        elif api_path == '/case/update-status':
            result = update_case_status_tool(params)
        elif api_path == '/finding/add':
            result = add_finding_tool(params)
        elif api_path == '/gate/set-decision':
            result = set_gate_decision_tool(params)
        elif api_path == '/case/get-snapshot':
            result = get_case_snapshot_tool(params)
        else:
            result = {'error': f'Unknown action: {api_path}'}
        
        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': action,
                'apiPath': api_path,
                'httpMethod': 'POST',
                'httpStatusCode': 200,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps(result)
                    }
                }
            }
        }
    except Exception as e:
        print(f"Error in tool: {str(e)}")
        return {
            'messageVersion': '1.0',
            'response': {
                'actionGroup': action,
                'apiPath': api_path,
                'httpMethod': 'POST',
                'httpStatusCode': 500,
                'responseBody': {
                    'application/json': {
                        'body': json.dumps({'error': str(e)})
                    }
                }
            }
        }

def create_case_tool(params):
    """Crear nuevo caso"""
    import uuid
    
    case_id = str(uuid.uuid4())
    now = datetime.utcnow().isoformat()
    
    item = {
        'case_id': case_id,
        'scope': params.get('scope', 'basic'),
        'status': 'created',
        'created_at': now,
        'current_phase': 'F1',
        'property_summary': json.loads(params.get('property_summary', '{}')),
        'parties_summary': json.loads(params.get('parties_summary', '{}'))
    }
    
    cases_table.put_item(Item=item)
    
    return {'case_id': case_id, 'status': 'created'}

def get_case_tool(params):
    """Obtener caso"""
    case_id = params.get('case_id')
    
    result = cases_table.get_item(Key={'case_id': case_id})
    
    if 'Item' not in result:
        return {'error': 'Case not found'}
    
    return result['Item']

def update_case_status_tool(params):
    """Actualizar status del caso"""
    case_id = params.get('case_id')
    status = params.get('status')
    phase = params.get('phase')
    
    update_expr = "SET #status = :status, updated_at = :updated_at"
    expr_values = {
        ':status': status,
        ':updated_at': datetime.utcnow().isoformat()
    }
    expr_names = {'#status': 'status'}
    
    if phase:
        update_expr += ", current_phase = :phase"
        expr_values[':phase'] = phase
    
    result = cases_table.update_item(
        Key={'case_id': case_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=expr_names,
        ExpressionAttributeValues=expr_values,
        ReturnValues='ALL_NEW'
    )
    
    return result['Attributes']

def add_finding_tool(params):
    """Agregar hallazgo"""
    import uuid
    
    case_id = params.get('case_id')
    phase = params.get('phase')
    category = params.get('category')
    severity = params.get('severity')  # low, medium, high, critical
    description = params.get('description')
    recommendation = params.get('recommendation', '')
    evidence_refs = json.loads(params.get('evidence_refs', '[]'))
    
    finding_id = str(uuid.uuid4())
    now = datetime.utcnow().isoformat()
    
    item = {
        'case_id': case_id,
        'phase_finding_id': f"{phase}#{finding_id}",
        'finding_id': finding_id,
        'phase': phase,
        'category': category,
        'severity': severity,
        'description': description,
        'recommendation': recommendation,
        'evidence_refs': evidence_refs,
        'created_at': now
    }
    
    findings_table.put_item(Item=item)
    
    return {'finding_id': finding_id, 'status': 'created'}

def set_gate_decision_tool(params):
    """Establecer decisión de gate"""
    case_id = params.get('case_id')
    gate_id = params.get('gate_id')
    decision = params.get('decision')  # GO, GO_WITH_CONDITIONS, NO_GO
    rationale = params.get('rationale')
    evidence_refs = json.loads(params.get('evidence_refs', '[]'))
    
    now = datetime.utcnow().isoformat()
    
    item = {
        'case_id': case_id,
        'gate_id': gate_id,
        'decision': decision,
        'rationale': rationale,
        'evidence_refs': evidence_refs,
        'decided_at': now
    }
    
    gates_table.put_item(Item=item)
    
    return {'gate_id': gate_id, 'decision': decision}

def get_case_snapshot_tool(params):
    """Obtener snapshot completo del caso"""
    case_id = params.get('case_id')
    
    # Obtener caso
    case_result = cases_table.get_item(Key={'case_id': case_id})
    if 'Item' not in case_result:
        return {'error': 'Case not found'}
    
    case = case_result['Item']
    
    # Obtener findings
    findings_result = findings_table.query(
        KeyConditionExpression='case_id = :case_id',
        ExpressionAttributeValues={':case_id': case_id}
    )
    findings = findings_result.get('Items', [])
    
    # Obtener gates
    gates_result = gates_table.query(
        KeyConditionExpression='case_id = :case_id',
        ExpressionAttributeValues={':case_id': case_id}
    )
    gates = gates_result.get('Items', [])
    
    return {
        'case': case,
        'findings': findings,
        'findings_count': len(findings),
        'gates': gates,
        'gates_count': len(gates)
    }
