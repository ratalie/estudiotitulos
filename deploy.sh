#!/bin/bash
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Plataforma Estudio de Títulos - Deploy${NC}"
echo -e "${GREEN}========================================${NC}"

# Variables de configuración
export AWS_REGION=${AWS_REGION:-us-east-1}
export PROJECT_NAME="estudio-titulos"
export ENVIRONMENT=${ENVIRONMENT:-dev}
export STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}"

echo -e "${YELLOW}Configuración:${NC}"
echo "  Region: $AWS_REGION"
echo "  Environment: $ENVIRONMENT"
echo "  Stack: $STACK_NAME"
echo ""

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI no está instalado${NC}"
    exit 1
fi

# Verificar credenciales
echo -e "${YELLOW}Verificando credenciales AWS...${NC}"
aws sts get-caller-identity > /dev/null 2>&1 || {
    echo -e "${RED}Error: Credenciales AWS no configuradas${NC}"
    exit 1
}

export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ Cuenta AWS: $AWS_ACCOUNT_ID${NC}"

# Crear S3 bucket para deployment
export DEPLOYMENT_BUCKET="${STACK_NAME}-deployment-${AWS_ACCOUNT_ID}"
echo -e "${YELLOW}Creando bucket de deployment...${NC}"
aws s3 mb s3://${DEPLOYMENT_BUCKET} --region ${AWS_REGION} 2>/dev/null || echo "Bucket ya existe"
aws s3api put-bucket-versioning --bucket ${DEPLOYMENT_BUCKET} --versioning-configuration Status=Enabled

# Deploy en orden
echo -e "${YELLOW}Iniciando deployment...${NC}"

# 1. IAM Roles y Policies
echo -e "${YELLOW}[1/8] Desplegando IAM roles...${NC}"
bash scripts/deploy-iam.sh

# 2. S3 Buckets
echo -e "${YELLOW}[2/8] Desplegando S3 buckets...${NC}"
bash scripts/deploy-s3.sh

# 3. DynamoDB Tables
echo -e "${YELLOW}[3/8] Desplegando DynamoDB...${NC}"
bash scripts/deploy-dynamodb.sh

# 4. Lambda Functions
echo -e "${YELLOW}[4/8] Desplegando Lambda functions...${NC}"
bash scripts/deploy-lambdas.sh

# 5. API Gateway
echo -e "${YELLOW}[5/8] Desplegando API Gateway...${NC}"
bash scripts/deploy-api.sh

# 6. Bedrock Agents
echo -e "${YELLOW}[6/8] Desplegando Bedrock Agents...${NC}"
bash scripts/deploy-bedrock-agents.sh

# 7. Step Functions
echo -e "${YELLOW}[7/8] Desplegando Step Functions...${NC}"
bash scripts/deploy-stepfunctions.sh

# 8. Amplify
echo -e "${YELLOW}[8/8] Desplegando Amplify...${NC}"
bash scripts/deploy-amplify.sh

# Guardar outputs
echo -e "${YELLOW}Guardando outputs...${NC}"
bash scripts/save-outputs.sh

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Deployment completado exitosamente${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Outputs guardados en: outputs/${ENVIRONMENT}.json${NC}"
echo ""
echo "Para ver los endpoints:"
echo "  cat outputs/${ENVIRONMENT}.json"
