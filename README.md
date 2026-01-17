# Plataforma de Estudio de Títulos - MVP

Sistema automatizado para análisis de expedientes de estudio de títulos en Colombia usando AWS Bedrock Agents.

## 🚀 Quick Start

```bash
# 1. Configurar
export AWS_REGION=us-east-1
export ENVIRONMENT=dev

# 2. Desplegar (5-10 minutos)
chmod +x deploy.sh scripts/*.sh
./deploy.sh

# 3. Ver outputs
cat outputs/dev.json
```

**¡Listo!** Tu plataforma está funcionando en AWS.

Ver [QUICKSTART.md](QUICKSTART.md) para guía completa.

## 🎯 Objetivo del MVP

Convertir expedientes de estudio de títulos en:
- **Expediente digital único** (ingesta + normalización)
- **Extracción estructurada** (matrícula, tradición, gravámenes, partes, impuestos)
- **Análisis por fases + Gates** (decisiones y condiciones)
- **Reporte final** (estructura estándar + tabla de hallazgos + semáforo 🟢🟡🔴)

## 👥 Roles

- **Analista Legal**: Operador principal
- **Supervisor**: Revisión + aprobación
- **Cliente**: Status, entrega de docs, descarga de informe

## 📋 Alcance

### Estudio Básico
- Fases 1-6: Recepción → Tradición → Gravámenes → Tributario → Verificación vendedor

### Due Diligence
- Fases 1-9: Incluye urbanístico, tributario exhaustivo, verificación exhaustiva

## 🏗️ Arquitectura

Ver documentación detallada en:
- [Arquitectura Funcional](docs/architecture-functional.md)
- [Arquitectura Técnica AWS](docs/architecture-technical.md)
- [Modelo de Datos](docs/data-model.md)
- [Diseño de Agentes](docs/agents-design.md)

## 🚀 Stack Tecnológico

- **Frontend**: AWS Amplify (React/Next.js)
- **Auth**: Amazon Cognito (MFA + RBAC)
- **API**: API Gateway + Lambda
- **Workflow**: Step Functions
- **Storage**: S3 (KMS encrypted)
- **Database**: DynamoDB
- **AI/ML**: Amazon Bedrock (Agents + Knowledge Bases)
- **OCR**: Amazon Textract
- **Security**: WAF, CloudTrail, Config

## 📁 Estructura del Proyecto

```
├── docs/                    # Documentación
│   ├── adr/                # Architecture Decision Records
│   ├── architecture-*.md   # Diagramas de arquitectura
│   └── security.md         # Checklist de seguridad
├── infra/                  # Infraestructura como código (CDK/Terraform)
├── services/               # Servicios y Lambdas
│   ├── api/               # API handlers
│   ├── agents/            # Bedrock Agents configuration
│   └── workflows/         # Step Functions definitions
├── contracts/             # OpenAPI specs
└── scripts/              # Scripts de deployment
```

## 🔐 Seguridad

- Encriptación en reposo (KMS)
- MFA obligatorio
- RBAC con Cognito
- Auditoría completa (CloudTrail)
- WAF + rate limiting
- Redacción de PII en logs

## 📖 Documentación

- **[QUICKSTART.md](QUICKSTART.md)** - Guía rápida de deployment y uso
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Guía detallada de deployment
- **[RESUMEN_EJECUTIVO.md](RESUMEN_EJECUTIVO.md)** - Resumen ejecutivo completo
- **[docs/architecture-functional.md](docs/architecture-functional.md)** - Arquitectura funcional
- **[docs/architecture-technical.md](docs/architecture-technical.md)** - Arquitectura técnica AWS

## � Costos

**MVP (100 casos/mes)**: ~$86-165/mes

Incluye: Lambda, DynamoDB, S3, API Gateway, Bedrock, Textract, Step Functions, Amplify

## 🛠️ Comandos Útiles

```bash
# Deployment completo
./deploy.sh

# Deployment por componentes
bash scripts/deploy-iam.sh
bash scripts/deploy-s3.sh
bash scripts/deploy-dynamodb.sh
bash scripts/deploy-lambdas.sh
bash scripts/deploy-api.sh
bash scripts/deploy-bedrock-agents.sh
bash scripts/deploy-stepfunctions.sh
bash scripts/deploy-amplify.sh

# Ver logs
aws logs tail /aws/lambda/${STACK_NAME}-api-cases --follow

# Limpiar recursos
./scripts/cleanup.sh
```

## 🎯 Características

- ✅ API REST completa (8 endpoints)
- ✅ Autenticación Cognito (MFA)
- ✅ Bedrock Agent Orchestrator
- ✅ Step Functions workflow (9 fases)
- ✅ OCR con Textract
- ✅ Encriptación KMS
- ✅ Auditoría CloudTrail
- ✅ WAF habilitado
- ✅ Frontend Next.js + Amplify

## 📝 Licencia

Propietario - Todos los derechos reservados
