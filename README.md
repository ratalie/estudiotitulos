# Plataforma de Estudio de Títulos - MVP

Sistema automatizado para análisis de expedientes de estudio de títulos en Colombia usando AWS Bedrock Agents.

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

Ver carpeta `/docs` para:
- Guías de implementación
- ADRs (decisiones arquitectónicas)
- Runbooks operacionales
- API contracts (OpenAPI)

## 🛠️ Desarrollo

```bash
# Instalar dependencias
npm install

# Deploy infraestructura
cd infra && npm run deploy

# Tests
npm test
```

## 📝 Licencia

Propietario - Todos los derechos reservados
