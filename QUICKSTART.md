# Quick Start - Plataforma Estudio de Títulos

## 🚀 Deployment en 5 Minutos

### 1. Prerrequisitos

```bash
# Verificar AWS CLI
aws --version
aws configure

# Verificar Python
python3 --version

# Verificar permisos
aws sts get-caller-identity
```

### 2. Configurar Variables

```bash
export AWS_REGION=us-east-1
export ENVIRONMENT=dev
```

### 3. Desplegar

```bash
# Dar permisos
chmod +x deploy.sh scripts/*.sh

# Ejecutar deployment
./deploy.sh
```

Esto desplegará:
- ✅ IAM roles y policies
- ✅ S3 buckets (encriptados con KMS)
- ✅ DynamoDB tables
- ✅ Lambda functions (API + Agent tools)
- ✅ API Gateway + Cognito
- ✅ Bedrock Agent (Orchestrator)
- ✅ Step Functions (workflow)
- ✅ Amplify (frontend config)

**Tiempo estimado**: 5-10 minutos

### 4. Crear Usuario de Prueba

```bash
# Cargar variables
source outputs/dev.env

# Crear usuario analista
aws cognito-idp admin-create-user \
  --user-pool-id ${USER_POOL_ID} \
  --username analista@test.com \
  --user-attributes Name=email,Value=analista@test.com Name=email_verified,Value=true \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

# Agregar a grupo
aws cognito-idp admin-add-user-to-group \
  --user-pool-id ${USER_POOL_ID} \
  --username analista@test.com \
  --group-name analyst
```

### 5. Probar API

```bash
# Obtener token
TOKEN=$(aws cognito-idp admin-initiate-auth \
  --user-pool-id ${USER_POOL_ID} \
  --client-id ${CLIENT_ID} \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=analista@test.com,PASSWORD=YourNewPassword123! \
  --query 'AuthenticationResult.IdToken' \
  --output text)

# Crear caso
curl -X POST ${API_ENDPOINT}/cases \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "scope": "basic",
    "property_summary": {
      "matricula": "050-12345",
      "direccion": "Calle 123 #45-67",
      "ciudad": "Bogotá"
    },
    "parties_summary": {
      "vendedor": "Juan Pérez",
      "comprador": "María García"
    }
  }'
```

### 6. Ejecutar Workflow

```bash
# Iniciar workflow (reemplaza CASE_ID)
aws stepfunctions start-execution \
  --state-machine-arn ${STATE_MACHINE_ARN} \
  --input '{"case_id":"CASE_ID_FROM_PREVIOUS_STEP"}' \
  --name "execution-$(date +%s)"
```

## 📊 Verificar Deployment

```bash
# Ver todos los recursos desplegados
cat outputs/dev.json

# Ver endpoints
echo "API: ${API_ENDPOINT}"
echo "User Pool: ${USER_POOL_ID}"
echo "Agent ID: ${AGENT_ID}"
```

## 🧪 Casos de Uso

### Caso 1: Estudio Básico

```bash
# 1. Crear caso básico
CASE_ID=$(curl -X POST ${API_ENDPOINT}/cases \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"scope":"basic","property_summary":{},"parties_summary":{}}' \
  | jq -r '.case_id')

# 2. Subir documento (base64 encoded)
curl -X POST ${API_ENDPOINT}/documents \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"case_id\": \"${CASE_ID}\",
    \"doc_type\": \"escritura\",
    \"file_name\": \"escritura.pdf\",
    \"file_content\": \"$(base64 -w 0 escritura.pdf)\"
  }"

# 3. Iniciar workflow
aws stepfunctions start-execution \
  --state-machine-arn ${STATE_MACHINE_ARN} \
  --input "{\"case_id\":\"${CASE_ID}\"}"
```

### Caso 2: Due Diligence

```bash
# Crear caso DD
curl -X POST ${API_ENDPOINT}/cases \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "scope": "dd",
    "property_summary": {
      "matricula": "050-67890",
      "tipo": "comercial"
    }
  }'
```

## 🔍 Monitoreo

### Ver Logs

```bash
# Logs de Lambda
aws logs tail /aws/lambda/${STACK_NAME}-api-cases --follow

# Logs de Step Functions
aws logs tail /aws/states/${STACK_NAME}-workflow --follow
```

### Ver Métricas

```bash
# Invocaciones de Lambda
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=${STACK_NAME}-api-cases \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## 🛠️ Troubleshooting

### Error: "Access Denied"
```bash
# Verificar credenciales
aws sts get-caller-identity

# Verificar permisos
aws iam get-user
```

### Error: "Bucket already exists"
```bash
# Cambiar nombre del stack
export PROJECT_NAME="estudio-titulos-v2"
./deploy.sh
```

### Error: "Bedrock not available"
```bash
# Verificar región
aws bedrock list-foundation-models --region us-east-1

# Cambiar región si necesario
export AWS_REGION=us-west-2
```

## 🧹 Limpieza

```bash
# ADVERTENCIA: Elimina TODOS los recursos
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

## 📚 Documentación Completa

- [Deployment Guide](DEPLOYMENT.md) - Guía detallada de deployment
- [Architecture Functional](docs/architecture-functional.md) - Arquitectura funcional
- [Architecture Technical](docs/architecture-technical.md) - Arquitectura técnica AWS
- [README](README.md) - Información general del proyecto

## 💰 Costos

**MVP (100 casos/mes)**: ~$86-165/mes

Incluye:
- Lambda, DynamoDB, S3, API Gateway
- Bedrock (Claude Sonnet)
- Textract
- Step Functions
- Amplify

## 🔐 Seguridad

- ✅ Encriptación KMS en reposo
- ✅ HTTPS obligatorio
- ✅ MFA disponible
- ✅ Auditoría con CloudTrail
- ✅ WAF habilitado
- ✅ Redacción de PII en logs

## 📞 Soporte

Para problemas:
1. Revisar logs en CloudWatch
2. Verificar `outputs/dev.json`
3. Consultar documentación AWS
4. Abrir issue en GitHub

## 🎯 Próximos Pasos

1. ✅ Deployment completado
2. ⬜ Conectar repositorio a Amplify
3. ⬜ Configurar dominio personalizado
4. ⬜ Agregar más agentes especializados
5. ⬜ Implementar generación de reportes PDF
6. ⬜ Configurar alertas CloudWatch
7. ⬜ Setup CI/CD pipeline
