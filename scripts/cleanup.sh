#!/bin/bash
set -e

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}========================================${NC}"
echo -e "${RED}ADVERTENCIA: LIMPIEZA DE RECURSOS${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo "Este script eliminará TODOS los recursos de:"
echo "  Stack: ${STACK_NAME}"
echo "  Region: ${AWS_REGION}"
echo "  Account: ${AWS_ACCOUNT_ID}"
echo ""
echo -e "${YELLOW}Recursos a eliminar:${NC}"
echo "  - Amplify App"
echo "  - Step Functions"
echo "  - Bedrock Agent"
echo "  - API Gateway"
echo "  - Lambda Functions"
echo "  - DynamoDB Tables"
echo "  - S3 Buckets (y todo su contenido)"
echo "  - Cognito User Pool"
echo "  - IAM Roles"
echo "  - KMS Keys"
echo ""
read -p "¿Estás seguro? Escribe 'DELETE' para confirmar: " confirm

if [ "$confirm" != "DELETE" ]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo "Iniciando limpieza..."

# Amplify
echo "Eliminando Amplify..."
APP_ID=$(aws amplify list-apps --query "apps[?name=='${STACK_NAME}-frontend'].appId | [0]" --output text 2>/dev/null)
if [ "$APP_ID" != "None" ] && [ -n "$APP_ID" ]; then
    aws amplify delete-app --app-id ${APP_ID} 2>/dev/null || true
fi

# Step Functions
echo "Eliminando Step Functions..."
STATE_MACHINE_ARN=$(aws stepfunctions list-state-machines --query "stateMachines[?name=='${STACK_NAME}-workflow'].stateMachineArn | [0]" --output text 2>/dev/null)
if [ "$STATE_MACHINE_ARN" != "None" ] && [ -n "$STATE_MACHINE_ARN" ]; then
    aws stepfunctions delete-state-machine --state-machine-arn ${STATE_MACHINE_ARN} 2>/dev/null || true
fi

# Bedrock Agent
echo "Eliminando Bedrock Agent..."
AGENT_ID=$(aws bedrock-agent list-agents --query "agentSummaries[?agentName=='${STACK_NAME}-orchestrator'].agentId | [0]" --output text 2>/dev/null)
if [ "$AGENT_ID" != "None" ] && [ -n "$AGENT_ID" ]; then
    aws bedrock-agent delete-agent --agent-id ${AGENT_ID} --skip-resource-in-use-check 2>/dev/null || true
fi

# API Gateway
echo "Eliminando API Gateway..."
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='${STACK_NAME}-api'].id | [0]" --output text 2>/dev/null)
if [ "$API_ID" != "None" ] && [ -n "$API_ID" ]; then
    aws apigateway delete-rest-api --rest-api-id ${API_ID} 2>/dev/null || true
fi

# Cognito
echo "Eliminando Cognito User Pool..."
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 10 --query "UserPools[?Name=='${STACK_NAME}-users'].Id | [0]" --output text 2>/dev/null)
if [ "$USER_POOL_ID" != "None" ] && [ -n "$USER_POOL_ID" ]; then
    aws cognito-idp delete-user-pool --user-pool-id ${USER_POOL_ID} 2>/dev/null || true
fi

# Lambda Functions
echo "Eliminando Lambda Functions..."
for func in api-cases api-documents agent-case-tools; do
    aws lambda delete-function --function-name ${STACK_NAME}-${func} 2>/dev/null || true
done

# DynamoDB Tables
echo "Eliminando DynamoDB Tables..."
for table in cases documents extractions findings gates audit-events; do
    aws dynamodb delete-table --table-name ${STACK_NAME}-${table} 2>/dev/null || true
done

# S3 Buckets (vaciar primero)
echo "Eliminando S3 Buckets..."
for bucket in raw-docs processed-docs reports knowledge-base deployment; do
    BUCKET_NAME="${STACK_NAME}-${bucket}"
    if aws s3 ls s3://${BUCKET_NAME} 2>/dev/null; then
        echo "  Vaciando ${BUCKET_NAME}..."
        aws s3 rm s3://${BUCKET_NAME} --recursive 2>/dev/null || true
        aws s3 rb s3://${BUCKET_NAME} --force 2>/dev/null || true
    fi
done

# IAM Roles
echo "Eliminando IAM Roles..."
for role in lambda-execution-role bedrock-agent-role stepfunctions-role; do
    ROLE_NAME="${STACK_NAME}-${role}"
    # Eliminar policies inline primero
    POLICIES=$(aws iam list-role-policies --role-name ${ROLE_NAME} --query 'PolicyNames' --output text 2>/dev/null)
    for policy in ${POLICIES}; do
        aws iam delete-role-policy --role-name ${ROLE_NAME} --policy-name ${policy} 2>/dev/null || true
    done
    # Eliminar role
    aws iam delete-role --role-name ${ROLE_NAME} 2>/dev/null || true
done

# KMS Key (programar eliminación)
echo "Programando eliminación de KMS Key..."
KMS_ALIAS="alias/${STACK_NAME}-key"
KEY_ID=$(aws kms describe-key --key-id ${KMS_ALIAS} --query 'KeyMetadata.KeyId' --output text 2>/dev/null)
if [ "$KEY_ID" != "None" ] && [ -n "$KEY_ID" ]; then
    aws kms schedule-key-deletion --key-id ${KEY_ID} --pending-window-in-days 7 2>/dev/null || true
    aws kms delete-alias --alias-name ${KMS_ALIAS} 2>/dev/null || true
fi

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Limpieza completada${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Nota: Algunos recursos pueden tardar unos minutos en eliminarse completamente."
echo "La KMS Key se eliminará en 7 días (período de espera obligatorio)."
