#!/bin/bash
set -e

echo "Guardando outputs del deployment..."

mkdir -p outputs

# Combinar todos los outputs
cat > outputs/${ENVIRONMENT}.json <<EOF
{
  "environment": "${ENVIRONMENT}",
  "region": "${AWS_REGION}",
  "account_id": "${AWS_ACCOUNT_ID}",
  "stack_name": "${STACK_NAME}",
  "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "api": $(cat /tmp/api-outputs.json 2>/dev/null || echo '{}'),
  "bedrock_agent": $(cat /tmp/bedrock-agent-ids.json 2>/dev/null || echo '{}'),
  "step_functions": $(cat /tmp/stepfunctions-outputs.json 2>/dev/null || echo '{}'),
  "amplify": $(cat /tmp/amplify-outputs.json 2>/dev/null || echo '{}'),
  "s3_buckets": {
    "raw_docs": "${STACK_NAME}-raw-docs",
    "processed_docs": "${STACK_NAME}-processed-docs",
    "reports": "${STACK_NAME}-reports",
    "knowledge_base": "${STACK_NAME}-knowledge-base"
  },
  "dynamodb_tables": {
    "cases": "${STACK_NAME}-cases",
    "documents": "${STACK_NAME}-documents",
    "extractions": "${STACK_NAME}-extractions",
    "findings": "${STACK_NAME}-findings",
    "gates": "${STACK_NAME}-gates",
    "audit_events": "${STACK_NAME}-audit-events"
  },
  "lambda_functions": {
    "api_cases": "${STACK_NAME}-api-cases",
    "api_documents": "${STACK_NAME}-api-documents",
    "agent_case_tools": "${STACK_NAME}-agent-case-tools"
  }
}
EOF

# Crear archivo de variables de entorno
cat > outputs/${ENVIRONMENT}.env <<EOF
# AWS Configuration
AWS_REGION=${AWS_REGION}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
ENVIRONMENT=${ENVIRONMENT}

# API
API_ENDPOINT=$(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"api_endpoint": "[^"]*' | cut -d'"' -f4)
USER_POOL_ID=$(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"user_pool_id": "[^"]*' | cut -d'"' -f4)
CLIENT_ID=$(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"client_id": "[^"]*' | cut -d'"' -f4)

# Bedrock Agent
AGENT_ID=$(cat /tmp/bedrock-agent-ids.json 2>/dev/null | grep -o '"agent_id": "[^"]*' | cut -d'"' -f4)
AGENT_ALIAS_ID=$(cat /tmp/bedrock-agent-ids.json 2>/dev/null | grep -o '"agent_alias_id": "[^"]*' | cut -d'"' -f4)

# Step Functions
STATE_MACHINE_ARN=$(cat /tmp/stepfunctions-outputs.json 2>/dev/null | grep -o '"state_machine_arn": "[^"]*' | cut -d'"' -f4)

# S3 Buckets
RAW_BUCKET=${STACK_NAME}-raw-docs
PROCESSED_BUCKET=${STACK_NAME}-processed-docs
REPORTS_BUCKET=${STACK_NAME}-reports

# DynamoDB Tables
CASES_TABLE=${STACK_NAME}-cases
DOCUMENTS_TABLE=${STACK_NAME}-documents
FINDINGS_TABLE=${STACK_NAME}-findings
GATES_TABLE=${STACK_NAME}-gates
EOF

# Crear README con instrucciones
cat > outputs/README.md <<EOF
# Deployment Outputs - ${ENVIRONMENT}

Deployment completado el: $(date)

## Endpoints

### API Gateway
- **Endpoint**: $(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"api_endpoint": "[^"]*' | cut -d'"' -f4)
- **User Pool**: $(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"user_pool_id": "[^"]*' | cut -d'"' -f4)

### Amplify
- **URL**: $(cat /tmp/amplify-outputs.json 2>/dev/null | grep -o '"app_url": "[^"]*' | cut -d'"' -f4)

### Bedrock Agent
- **Agent ID**: $(cat /tmp/bedrock-agent-ids.json 2>/dev/null | grep -o '"agent_id": "[^"]*' | cut -d'"' -f4)

## Crear Usuario de Prueba

\`\`\`bash
aws cognito-idp admin-create-user \\
  --user-pool-id $(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"user_pool_id": "[^"]*' | cut -d'"' -f4) \\
  --username test@example.com \\
  --user-attributes Name=email,Value=test@example.com Name=email_verified,Value=true \\
  --temporary-password TempPass123! \\
  --message-action SUPPRESS

aws cognito-idp admin-add-user-to-group \\
  --user-pool-id $(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"user_pool_id": "[^"]*' | cut -d'"' -f4) \\
  --username test@example.com \\
  --group-name analyst
\`\`\`

## Probar API

\`\`\`bash
# Obtener token
aws cognito-idp admin-initiate-auth \\
  --user-pool-id $(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"user_pool_id": "[^"]*' | cut -d'"' -f4) \\
  --client-id $(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"client_id": "[^"]*' | cut -d'"' -f4) \\
  --auth-flow ADMIN_NO_SRP_AUTH \\
  --auth-parameters USERNAME=test@example.com,PASSWORD=YourPassword123!

# Crear caso
curl -X POST $(cat /tmp/api-outputs.json 2>/dev/null | grep -o '"api_endpoint": "[^"]*' | cut -d'"' -f4)/cases \\
  -H "Authorization: Bearer YOUR_TOKEN" \\
  -H "Content-Type: application/json" \\
  -d '{"scope":"basic","property_summary":{},"parties_summary":{}}'
\`\`\`

## Ejecutar Workflow

\`\`\`bash
aws stepfunctions start-execution \\
  --state-machine-arn $(cat /tmp/stepfunctions-outputs.json 2>/dev/null | grep -o '"state_machine_arn": "[^"]*' | cut -d'"' -f4) \\
  --input '{"case_id":"YOUR_CASE_ID"}'
\`\`\`

## Recursos Desplegados

Ver archivo \`${ENVIRONMENT}.json\` para detalles completos.
EOF

echo "✓ Outputs guardados en outputs/${ENVIRONMENT}.json"
