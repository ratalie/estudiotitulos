# Guía de Deployment

## Prerrequisitos

1. **AWS CLI** instalado y configurado
   ```bash
   aws --version
   aws configure
   ```

2. **Python 3.11+** instalado
   ```bash
   python3 --version
   pip3 --version
   ```

3. **Node.js 18+** (para frontend)
   ```bash
   node --version
   npm --version
   ```

4. **Permisos AWS** necesarios:
   - IAM (crear roles y policies)
   - S3 (crear buckets)
   - DynamoDB (crear tablas)
   - Lambda (crear funciones)
   - API Gateway (crear APIs)
   - Bedrock (crear agentes)
   - Step Functions (crear state machines)
   - Cognito (crear user pools)
   - Amplify (crear apps)
   - CloudWatch (logs)
   - KMS (crear keys)

## Deployment Completo

### 1. Configurar Variables de Entorno

```bash
export AWS_REGION=us-east-1
export ENVIRONMENT=dev
```

### 2. Ejecutar Deployment

```bash
# Dar permisos de ejecución
chmod +x deploy.sh
chmod +x scripts/*.sh

# Ejecutar deployment completo
./deploy.sh
```

El script desplegará en orden:
1. IAM roles y policies
2. S3 buckets (con encriptación KMS)
3. DynamoDB tables
4. Lambda functions
5. API Gateway + Cognito
6. Bedrock Agents
7. Step Functions
8. Amplify (configuración)

### 3. Verificar Deployment

```bash
# Ver outputs
cat outputs/dev.json

# Ver variables de entorno
cat outputs/dev.env
```

## Deployment por Componentes

Si prefieres desplegar componentes individuales:

```bash
# Solo IAM
bash scripts/deploy-iam.sh

# Solo S3
bash scripts/deploy-s3.sh

# Solo DynamoDB
bash scripts/deploy-dynamodb.sh

# Solo Lambdas
bash scripts/deploy-lambdas.sh

# Solo API Gateway
bash scripts/deploy-api.sh

# Solo Bedrock Agents
bash scripts/deploy-bedrock-agents.sh

# Solo Step Functions
bash scripts/deploy-stepfunctions.sh

# Solo Amplify
bash scripts/deploy-amplify.sh
```

## Post-Deployment

### Crear Usuario de Prueba

```bash
# Cargar variables
source outputs/dev.env

# Crear usuario
aws cognito-idp admin-create-user \
  --user-pool-id ${USER_POOL_ID} \
  --username analista@example.com \
  --user-attributes Name=email,Value=analista@example.com Name=email_verified,Value=true \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

# Agregar a grupo
aws cognito-idp admin-add-user-to-group \
  --user-pool-id ${USER_POOL_ID} \
  --username analista@example.com \
  --group-name analyst
```

### Probar API

```bash
# 1. Obtener token
TOKEN=$(aws cognito-idp admin-initiate-auth \
  --user-pool-id ${USER_POOL_ID} \
  --client-id ${CLIENT_ID} \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=analista@example.com,PASSWORD=YourNewPassword123! \
  --query 'AuthenticationResult.IdToken' \
  --output text)

# 2. Crear caso
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

# 3. Listar casos
curl -X GET ${API_ENDPOINT}/cases \
  -H "Authorization: Bearer ${TOKEN}"
```

### Ejecutar Workflow

```bash
# Iniciar workflow para un caso
aws stepfunctions start-execution \
  --state-machine-arn ${STATE_MACHINE_ARN} \
  --input '{"case_id":"CASE_ID_FROM_API"}' \
  --name "execution-$(date +%s)"

# Ver estado de ejecución
aws stepfunctions list-executions \
  --state-machine-arn ${STATE_MACHINE_ARN} \
  --max-results 5
```

### Probar Bedrock Agent

```bash
# Invocar agente directamente
aws bedrock-agent-runtime invoke-agent \
  --agent-id ${AGENT_ID} \
  --agent-alias-id ${AGENT_ALIAS_ID} \
  --session-id "test-session-$(date +%s)" \
  --input-text "Crear un nuevo caso de estudio básico para la matrícula 050-12345" \
  /tmp/agent-response.txt

cat /tmp/agent-response.txt
```

## Actualizar Deployment

Para actualizar componentes existentes:

```bash
# Actualizar Lambdas
bash scripts/deploy-lambdas.sh

# Actualizar Bedrock Agent
bash scripts/deploy-bedrock-agents.sh

# Actualizar Step Functions
bash scripts/deploy-stepfunctions.sh
```

## Troubleshooting

### Error: "Role not found"
Espera 10-15 segundos después de crear roles IAM antes de usarlos.

### Error: "Bucket already exists"
Los buckets S3 son globales. Cambia el nombre del stack o usa otro environment.

### Error: "Bedrock not available"
Verifica que Bedrock esté disponible en tu región. Usa `us-east-1` o `us-west-2`.

### Error: "Lambda timeout"
Aumenta el timeout en `scripts/deploy-lambdas.sh` (línea con `--timeout`).

## Limpieza

Para eliminar todos los recursos:

```bash
# ADVERTENCIA: Esto eliminará TODOS los recursos
bash scripts/cleanup.sh
```

## Costos Estimados (MVP)

- **DynamoDB**: ~$5-10/mes (on-demand)
- **Lambda**: ~$5-20/mes (según uso)
- **S3**: ~$5-15/mes (según almacenamiento)
- **API Gateway**: ~$3.50 por millón de requests
- **Bedrock**: ~$0.003 por 1K tokens (Claude Sonnet)
- **Textract**: ~$1.50 por 1K páginas
- **Step Functions**: ~$25 por millón de transiciones
- **Amplify**: ~$0.01 por GB servido

**Total estimado**: $50-150/mes para MVP con uso moderado

## Seguridad

- Todos los buckets S3 tienen encriptación KMS
- DynamoDB tables encriptadas
- MFA recomendado para usuarios
- CloudTrail habilitado para auditoría
- Secrets nunca en código
- HTTPS obligatorio en API Gateway

## Soporte

Para problemas o preguntas:
1. Revisa los logs en CloudWatch
2. Verifica outputs en `outputs/dev.json`
3. Consulta la documentación de AWS
