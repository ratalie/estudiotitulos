#!/bin/bash
set -e

echo "Desplegando Lambda functions..."

LAMBDA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${STACK_NAME}-lambda-execution-role"

# Función para crear/actualizar Lambda
deploy_lambda() {
    local function_name=$1
    local handler=$2
    local source_dir=$3
    local description=$4
    
    echo "  Desplegando ${function_name}..."
    
    # Crear directorio temporal
    temp_dir=$(mktemp -d)
    
    # Copiar código
    cp -r ${source_dir}/* ${temp_dir}/
    
    # Instalar dependencias si existe requirements.txt
    if [ -f "${source_dir}/requirements.txt" ]; then
        pip install -r ${source_dir}/requirements.txt -t ${temp_dir}/ --quiet
    fi
    
    # Crear ZIP
    cd ${temp_dir}
    zip -r /tmp/${function_name}.zip . > /dev/null
    cd - > /dev/null
    
    # Crear o actualizar función
    aws lambda create-function \
        --function-name ${function_name} \
        --runtime python3.11 \
        --role ${LAMBDA_ROLE_ARN} \
        --handler ${handler} \
        --description "${description}" \
        --timeout 300 \
        --memory-size 512 \
        --environment "Variables={
            CASES_TABLE=${STACK_NAME}-cases,
            DOCUMENTS_TABLE=${STACK_NAME}-documents,
            EXTRACTIONS_TABLE=${STACK_NAME}-extractions,
            FINDINGS_TABLE=${STACK_NAME}-findings,
            GATES_TABLE=${STACK_NAME}-gates,
            AUDIT_TABLE=${STACK_NAME}-audit-events,
            RAW_BUCKET=${STACK_NAME}-raw-docs,
            PROCESSED_BUCKET=${STACK_NAME}-processed-docs,
            REPORTS_BUCKET=${STACK_NAME}-reports,
            REGION=${AWS_REGION}
        }" \
        --zip-file fileb:///tmp/${function_name}.zip \
        --tags Project=${PROJECT_NAME},Environment=${ENVIRONMENT} \
        2>/dev/null || \
    aws lambda update-function-code \
        --function-name ${function_name} \
        --zip-file fileb:///tmp/${function_name}.zip > /dev/null
    
    # Actualizar configuración
    aws lambda update-function-configuration \
        --function-name ${function_name} \
        --environment "Variables={
            CASES_TABLE=${STACK_NAME}-cases,
            DOCUMENTS_TABLE=${STACK_NAME}-documents,
            EXTRACTIONS_TABLE=${STACK_NAME}-extractions,
            FINDINGS_TABLE=${STACK_NAME}-findings,
            GATES_TABLE=${STACK_NAME}-gates,
            AUDIT_TABLE=${STACK_NAME}-audit-events,
            RAW_BUCKET=${STACK_NAME}-raw-docs,
            PROCESSED_BUCKET=${STACK_NAME}-processed-docs,
            REPORTS_BUCKET=${STACK_NAME}-reports,
            REGION=${AWS_REGION}
        }" > /dev/null
    
    # Limpiar
    rm -rf ${temp_dir}
    rm /tmp/${function_name}.zip
    
    echo "    ✓ ${function_name} desplegado"
}

# Desplegar funciones API
deploy_lambda \
    "${STACK_NAME}-api-cases" \
    "handler.lambda_handler" \
    "services/api/cases" \
    "API handler for cases management"

deploy_lambda \
    "${STACK_NAME}-api-documents" \
    "handler.lambda_handler" \
    "services/api/documents" \
    "API handler for documents management"

# Desplegar tools para Bedrock Agent
deploy_lambda \
    "${STACK_NAME}-agent-case-tools" \
    "case_tools.lambda_handler" \
    "services/agents/tools" \
    "Bedrock Agent tools for case management"

# Dar permisos a Bedrock para invocar Lambda
aws lambda add-permission \
    --function-name ${STACK_NAME}-agent-case-tools \
    --statement-id bedrock-invoke \
    --action lambda:InvokeFunction \
    --principal bedrock.amazonaws.com \
    --source-account ${AWS_ACCOUNT_ID} \
    2>/dev/null || echo "Permission already exists"

# Esperar a que las funciones estén activas
echo "Esperando a que las funciones estén activas..."
for func in api-cases api-documents agent-case-tools; do
    aws lambda wait function-active --function-name ${STACK_NAME}-${func}
done

echo "✓ Lambda functions desplegadas"
