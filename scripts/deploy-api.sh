#!/bin/bash
set -e

echo "Desplegando API Gateway..."

# Crear API REST
API_ID=$(aws apigateway create-rest-api \
    --name "${STACK_NAME}-api" \
    --description "API for Estudio de Títulos platform" \
    --endpoint-configuration types=REGIONAL \
    --query 'id' \
    --output text 2>/dev/null || \
aws apigateway get-rest-apis \
    --query "items[?name=='${STACK_NAME}-api'].id | [0]" \
    --output text)

echo "API ID: ${API_ID}"

# Obtener root resource
ROOT_ID=$(aws apigateway get-resources \
    --rest-api-id ${API_ID} \
    --query 'items[?path==`/`].id | [0]' \
    --output text)

# Crear recursos
create_resource() {
    local parent_id=$1
    local path_part=$2
    
    aws apigateway create-resource \
        --rest-api-id ${API_ID} \
        --parent-id ${parent_id} \
        --path-part ${path_part} \
        --query 'id' \
        --output text 2>/dev/null || \
    aws apigateway get-resources \
        --rest-api-id ${API_ID} \
        --query "items[?pathPart=='${path_part}'].id | [0]" \
        --output text
}

# Crear estructura de recursos
CASES_ID=$(create_resource ${ROOT_ID} "cases")
CASE_ID_ID=$(create_resource ${CASES_ID} "{case_id}")
DOCS_ID=$(create_resource ${ROOT_ID} "documents")
DOC_ID_ID=$(create_resource ${DOCS_ID} "{doc_id}")

# Función para crear método
create_method() {
    local resource_id=$1
    local http_method=$2
    local lambda_function=$3
    
    # Crear método
    aws apigateway put-method \
        --rest-api-id ${API_ID} \
        --resource-id ${resource_id} \
        --http-method ${http_method} \
        --authorization-type COGNITO_USER_POOLS \
        --authorizer-id ${AUTHORIZER_ID} \
        2>/dev/null || echo "Method exists"
    
    # Integración con Lambda
    LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${lambda_function}"
    
    aws apigateway put-integration \
        --rest-api-id ${API_ID} \
        --resource-id ${resource_id} \
        --http-method ${http_method} \
        --type AWS_PROXY \
        --integration-http-method POST \
        --uri "arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" \
        2>/dev/null || echo "Integration exists"
    
    # Dar permiso a API Gateway para invocar Lambda
    aws lambda add-permission \
        --function-name ${lambda_function} \
        --statement-id apigateway-${resource_id}-${http_method} \
        --action lambda:InvokeFunction \
        --principal apigateway.amazonaws.com \
        --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/${http_method}/*" \
        2>/dev/null || echo "Permission exists"
}

# Crear Cognito User Pool (simplificado para MVP)
USER_POOL_ID=$(aws cognito-idp create-user-pool \
    --pool-name "${STACK_NAME}-users" \
    --policies "PasswordPolicy={MinimumLength=8,RequireUppercase=true,RequireLowercase=true,RequireNumbers=true,RequireSymbols=true}" \
    --mfa-configuration OPTIONAL \
    --auto-verified-attributes email \
    --query 'UserPool.Id' \
    --output text 2>/dev/null || \
aws cognito-idp list-user-pools \
    --max-results 10 \
    --query "UserPools[?Name=='${STACK_NAME}-users'].Id | [0]" \
    --output text)

echo "User Pool ID: ${USER_POOL_ID}"

# Crear User Pool Client
CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id ${USER_POOL_ID} \
    --client-name "${STACK_NAME}-client" \
    --generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --query 'UserPoolClient.ClientId' \
    --output text 2>/dev/null || \
aws cognito-idp list-user-pool-clients \
    --user-pool-id ${USER_POOL_ID} \
    --query "UserPoolClients[?ClientName=='${STACK_NAME}-client'].ClientId | [0]" \
    --output text)

echo "Client ID: ${CLIENT_ID}"

# Crear grupos
for group in analyst supervisor client; do
    aws cognito-idp create-group \
        --user-pool-id ${USER_POOL_ID} \
        --group-name ${group} \
        --description "${group} role" \
        2>/dev/null || echo "Group ${group} exists"
done

# Crear authorizer
AUTHORIZER_ID=$(aws apigateway create-authorizer \
    --rest-api-id ${API_ID} \
    --name "${STACK_NAME}-authorizer" \
    --type COGNITO_USER_POOLS \
    --provider-arns "arn:aws:cognito-idp:${AWS_REGION}:${AWS_ACCOUNT_ID}:userpool/${USER_POOL_ID}" \
    --identity-source "method.request.header.Authorization" \
    --query 'id' \
    --output text 2>/dev/null || \
aws apigateway get-authorizers \
    --rest-api-id ${API_ID} \
    --query "items[?name=='${STACK_NAME}-authorizer'].id | [0]" \
    --output text)

echo "Authorizer ID: ${AUTHORIZER_ID}"

# Crear métodos
create_method ${CASES_ID} POST ${STACK_NAME}-api-cases
create_method ${CASES_ID} GET ${STACK_NAME}-api-cases
create_method ${CASE_ID_ID} GET ${STACK_NAME}-api-cases
create_method ${CASE_ID_ID} PUT ${STACK_NAME}-api-cases

create_method ${DOCS_ID} POST ${STACK_NAME}-api-documents
create_method ${DOCS_ID} GET ${STACK_NAME}-api-documents
create_method ${DOC_ID_ID} GET ${STACK_NAME}-api-documents

# Habilitar CORS
enable_cors() {
    local resource_id=$1
    
    aws apigateway put-method \
        --rest-api-id ${API_ID} \
        --resource-id ${resource_id} \
        --http-method OPTIONS \
        --authorization-type NONE \
        2>/dev/null || echo "OPTIONS exists"
    
    aws apigateway put-integration \
        --rest-api-id ${API_ID} \
        --resource-id ${resource_id} \
        --http-method OPTIONS \
        --type MOCK \
        --request-templates '{"application/json": "{\"statusCode\": 200}"}' \
        2>/dev/null || echo "CORS integration exists"
    
    aws apigateway put-method-response \
        --rest-api-id ${API_ID} \
        --resource-id ${resource_id} \
        --http-method OPTIONS \
        --status-code 200 \
        --response-parameters \
            "method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true,method.response.header.Access-Control-Allow-Origin=true" \
        2>/dev/null || echo "Method response exists"
    
    aws apigateway put-integration-response \
        --rest-api-id ${API_ID} \
        --resource-id ${resource_id} \
        --http-method OPTIONS \
        --status-code 200 \
        --response-parameters \
            "method.response.header.Access-Control-Allow-Headers='Content-Type,Authorization',method.response.header.Access-Control-Allow-Methods='GET,POST,PUT,DELETE,OPTIONS',method.response.header.Access-Control-Allow-Origin='*'" \
        2>/dev/null || echo "Integration response exists"
}

enable_cors ${CASES_ID}
enable_cors ${CASE_ID_ID}
enable_cors ${DOCS_ID}
enable_cors ${DOC_ID_ID}

# Crear deployment
DEPLOYMENT_ID=$(aws apigateway create-deployment \
    --rest-api-id ${API_ID} \
    --stage-name ${ENVIRONMENT} \
    --stage-description "${ENVIRONMENT} stage" \
    --description "Deployment $(date +%Y%m%d-%H%M%S)" \
    --query 'id' \
    --output text)

echo "Deployment ID: ${DEPLOYMENT_ID}"

# Guardar outputs
cat > /tmp/api-outputs.json <<EOF
{
  "api_id": "${API_ID}",
  "api_endpoint": "https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${ENVIRONMENT}",
  "user_pool_id": "${USER_POOL_ID}",
  "client_id": "${CLIENT_ID}",
  "authorizer_id": "${AUTHORIZER_ID}"
}
EOF

echo "✓ API Gateway desplegado"
echo "  Endpoint: https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${ENVIRONMENT}"
