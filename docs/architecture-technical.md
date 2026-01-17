# Arquitectura Técnica AWS - Plataforma Estudio de Títulos

## Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                         FRONTEND LAYER                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  AWS Amplify Hosting (React/Next.js)                     │  │
│  │  - CloudFront CDN                                        │  │
│  │  - S3 Static Hosting                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ HTTPS
┌─────────────────────────────────────────────────────────────────┐
│                      AUTHENTICATION LAYER                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Amazon Cognito                                          │  │
│  │  - User Pools (MFA enabled)                              │  │
│  │  - Groups: analyst, supervisor, client                   │  │
│  │  - JWT tokens                                            │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓ JWT
┌─────────────────────────────────────────────────────────────────┐
│                          API LAYER                              │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  API Gateway (REST)                                      │  │
│  │  - Cognito Authorizer                                    │  │
│  │  - WAF (rate limiting, bot control)                      │  │
│  │  - CloudWatch Logs                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                       COMPUTE LAYER                             │
│  ┌────────────────────┐  ┌────────────────────┐               │
│  │  Lambda Functions  │  │  Step Functions    │               │
│  │  - API handlers    │  │  - Workflow        │               │
│  │  - Agent tools     │  │  - Orchestration   │               │
│  │  - Processors      │  │  - Phase execution │               │
│  └────────────────────┘  └────────────────────┘               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                          AI LAYER                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Amazon Bedrock                                          │  │
│  │  ┌────────────────┐  ┌────────────────┐                 │  │
│  │  │ Bedrock Agent  │  │ Knowledge Base │                 │  │
│  │  │ (Orchestrator) │  │ (RAG)          │                 │  │
│  │  │ Claude Sonnet  │  │ OpenSearch     │                 │  │
│  │  └────────────────┘  └────────────────┘                 │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐ │  │
│  │  │  Amazon Textract                                   │ │  │
│  │  │  - Document Analysis                               │ │  │
│  │  │  - Forms & Tables Extraction                       │ │  │
│  │  └────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                        STORAGE LAYER                            │
│  ┌────────────────────┐  ┌────────────────────┐               │
│  │  Amazon S3         │  │  DynamoDB          │               │
│  │  - raw-docs        │  │  - cases           │               │
│  │  - processed-docs  │  │  - documents       │               │
│  │  - reports         │  │  - extractions     │               │
│  │  - knowledge-base  │  │  - findings        │               │
│  │  (KMS encrypted)   │  │  - gates           │               │
│  │                    │  │  - audit-events    │               │
│  └────────────────────┘  └────────────────────┘               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    MONITORING & SECURITY                        │
│  ┌────────────────┐  ┌────────────┐  ┌────────────────┐       │
│  │  CloudWatch    │  │ CloudTrail │  │  AWS Config    │       │
│  │  - Logs        │  │ - Audit    │  │  - Compliance  │       │
│  │  - Metrics     │  │ - Events   │  │  - Governance  │       │
│  │  - Alarms      │  │            │  │                │       │
│  └────────────────┘  └────────────┘  └────────────────┘       │
│                                                                 │
│  ┌────────────────┐  ┌────────────────────────────────┐       │
│  │  AWS KMS       │  │  AWS WAF                       │       │
│  │  - Encryption  │  │  - DDoS protection             │       │
│  │  - Key mgmt    │  │  - Rate limiting               │       │
│  └────────────────┘  └────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

## Stack Tecnológico Detallado

### Frontend
- **Framework**: Next.js 14 (React)
- **Hosting**: AWS Amplify
- **CDN**: CloudFront
- **Auth**: AWS Amplify Auth (Cognito)
- **API Client**: AWS Amplify API

### Backend
- **API**: API Gateway REST
- **Compute**: Lambda (Python 3.11)
- **Orchestration**: Step Functions
- **Auth**: Cognito User Pools

### AI/ML
- **LLM**: Amazon Bedrock (Claude 3 Sonnet)
- **Agents**: Bedrock Agents
- **RAG**: Bedrock Knowledge Bases
- **OCR**: Amazon Textract
- **Vector Store**: OpenSearch Serverless (managed by Bedrock KB)

### Data
- **NoSQL**: DynamoDB (on-demand)
- **Object Storage**: S3
- **Encryption**: KMS

### Security
- **WAF**: AWS WAF
- **Audit**: CloudTrail
- **Compliance**: AWS Config
- **Secrets**: Secrets Manager

### Monitoring
- **Logs**: CloudWatch Logs
- **Metrics**: CloudWatch Metrics
- **Tracing**: X-Ray (opcional)

## Componentes Detallados

### 1. API Gateway

**Endpoints**:
```
POST   /cases                    # Crear caso
GET    /cases                    # Listar casos
GET    /cases/{case_id}          # Obtener caso
PUT    /cases/{case_id}          # Actualizar caso

POST   /documents                # Subir documento
GET    /documents                # Listar documentos
GET    /documents/{doc_id}       # Obtener documento

GET    /findings                 # Listar hallazgos
POST   /findings                 # Agregar hallazgo

GET    /gates                    # Listar gates
POST   /gates                    # Establecer decisión

POST   /workflow/start           # Iniciar workflow
GET    /workflow/{execution_id}  # Estado de workflow

GET    /reports/{case_id}        # Descargar reporte
```

**Configuración**:
- Authorizer: Cognito User Pools
- Throttling: 1000 req/s burst, 500 req/s steady
- CORS habilitado
- CloudWatch Logs habilitado
- X-Ray tracing (opcional)

### 2. Lambda Functions

**api-cases**
- Handler: `handler.lambda_handler`
- Runtime: Python 3.11
- Memory: 512 MB
- Timeout: 30s
- Env vars: DynamoDB tables, S3 buckets

**api-documents**
- Handler: `handler.lambda_handler`
- Runtime: Python 3.11
- Memory: 512 MB
- Timeout: 300s (para uploads grandes)
- Env vars: DynamoDB tables, S3 buckets, Textract

**agent-case-tools**
- Handler: `case_tools.lambda_handler`
- Runtime: Python 3.11
- Memory: 512 MB
- Timeout: 300s
- Env vars: DynamoDB tables
- Permisos: Invocable por Bedrock

### 3. Bedrock Agent

**Configuración**:
- Model: Claude 3 Sonnet (`anthropic.claude-3-sonnet-20240229-v1:0`)
- Session TTL: 600s
- Action Groups: case-management-actions
- Tools: 6 herramientas (create_case, get_case, update_status, add_finding, set_gate, get_snapshot)

**Instrucciones**:
- Rol: Orchestrator para estudio de títulos
- Fases: F1-F9 según alcance
- Gates: GO/GO_WITH_CONDITIONS/NO_GO
- Severidad: low/medium/high/critical

### 4. Step Functions

**State Machine**: `estudio-titulos-workflow`

**Estados**:
1. GetCaseDetails (DynamoDB GetItem)
2. DetermineScope (Choice)
3. ProcessBasicScope (Parallel)
   - Phase1_Reception
   - Phase2_Documents
   - Phase3_Tradicion
   - Gate3_Tradicion
   - CheckGate3 (Choice)
   - Phase4_Gravamenes
   - Phase5_Tributario
   - Phase6_Vendedor
4. ProcessDDScope (Parallel)
   - Phases 1-6
   - Phase7_Urbanistico
   - Phase8_TributarioExhaustivo
   - Phase9_VendedorExhaustivo
5. ConsolidateResults
6. UpdateCaseStatus

**Integración**:
- Bedrock Agent (invoke-agent)
- DynamoDB (getItem, updateItem)

### 5. DynamoDB Tables

**cases**
- PK: case_id (String)
- GSI: created_at-index
- Attributes: scope, status, current_phase, property_summary, parties_summary
- Billing: On-demand
- Encryption: KMS

**documents**
- PK: doc_id (String)
- GSI: case_id-index
- Attributes: s3_uri, doc_type, file_hash, textract_job_id, processed
- Billing: On-demand
- Encryption: KMS

**extractions**
- PK: case_id (String)
- SK: doc_page (String, formato: doc_id#page_num)
- Attributes: entities_json, confidence, model_version
- Billing: On-demand
- Encryption: KMS

**findings**
- PK: case_id (String)
- SK: phase_finding_id (String, formato: phase#finding_id)
- Attributes: category, severity, description, recommendation, evidence_refs
- Billing: On-demand
- Encryption: KMS

**gates**
- PK: case_id (String)
- SK: gate_id (String)
- Attributes: decision, rationale, evidence_refs, decided_at
- Billing: On-demand
- Encryption: KMS

**audit-events**
- PK: case_id (String)
- SK: ts_event_id (String, formato: timestamp#event_id)
- Attributes: actor, action, payload_redacted
- Billing: On-demand
- Encryption: KMS

### 6. S3 Buckets

**raw-docs**
- Propósito: Documentos originales
- Versioning: Habilitado
- Encryption: KMS
- Lifecycle: Ninguna (retención permanente)
- Public Access: Bloqueado

**processed-docs**
- Propósito: Documentos procesados (OCR, normalización)
- Versioning: Habilitado
- Encryption: KMS
- Lifecycle: Ninguna
- Public Access: Bloqueado

**reports**
- Propósito: Reportes generados (PDF, DOCX)
- Versioning: Habilitado
- Encryption: KMS
- Lifecycle: Ninguna
- Public Access: Bloqueado

**knowledge-base**
- Propósito: Documentos para RAG (jurisprudencia, normativa)
- Versioning: Deshabilitado
- Encryption: KMS
- Lifecycle: Ninguna
- Public Access: Bloqueado

### 7. Cognito

**User Pool**
- MFA: Opcional (TOTP)
- Password Policy: Min 8 chars, uppercase, lowercase, numbers, symbols
- Auto-verified: Email
- Groups: analyst, supervisor, client

**User Pool Client**
- Auth Flows: USER_PASSWORD_AUTH, REFRESH_TOKEN_AUTH
- Token Validity: ID token 1h, Access token 1h, Refresh token 30d

## Seguridad

### Encriptación

**En Reposo**:
- S3: SSE-KMS
- DynamoDB: KMS
- Secrets Manager: KMS
- CloudWatch Logs: KMS (opcional)

**En Tránsito**:
- HTTPS obligatorio (TLS 1.2+)
- API Gateway: Certificate Manager
- CloudFront: Certificate Manager

### IAM Roles

**lambda-execution-role**
- Permisos: DynamoDB, S3, Textract, Bedrock, KMS, CloudWatch Logs

**bedrock-agent-role**
- Permisos: Bedrock InvokeModel, Lambda InvokeFunction, S3 GetObject

**stepfunctions-role**
- Permisos: Lambda InvokeFunction, Bedrock InvokeAgent, DynamoDB

### Network

**VPC**: No requerido para MVP (serverless público)
- Lambdas: Sin VPC (acceso público a servicios AWS)
- API Gateway: Regional endpoint
- S3: Acceso vía IAM

**Opcional para producción**:
- VPC con subnets privadas
- VPC Endpoints para S3, DynamoDB, Bedrock
- NAT Gateway para salida a internet

### WAF Rules

- Rate limiting: 2000 req/5min por IP
- Geo-blocking: Solo Colombia (opcional)
- Bot control: Managed rule group
- SQL injection protection
- XSS protection

### Auditoría

**CloudTrail**:
- Todos los eventos de API
- Retención: 90 días en CloudWatch, permanente en S3

**CloudWatch Logs**:
- Lambda logs: 30 días
- API Gateway logs: 30 días
- Step Functions logs: 30 días

**AWS Config**:
- Compliance checks
- Resource inventory
- Configuration history

## Escalabilidad

### Límites y Cuotas

**Lambda**:
- Concurrent executions: 1000 (default)
- Puede aumentarse vía Service Quotas

**DynamoDB**:
- On-demand: Auto-scaling
- Sin límite de throughput

**API Gateway**:
- 10,000 req/s (default)
- Puede aumentarse vía Service Quotas

**Bedrock**:
- Tokens/min: Según modelo y región
- Solicitar aumento si necesario

### Optimizaciones

**Lambda**:
- Provisioned concurrency para funciones críticas
- Lambda Layers para dependencias compartidas
- Reutilización de conexiones (DynamoDB, S3)

**DynamoDB**:
- GSI para queries frecuentes
- Batch operations para múltiples items
- DynamoDB Streams para procesamiento asíncrono

**S3**:
- Transfer Acceleration para uploads grandes
- Multipart upload para archivos >100MB
- CloudFront para distribución de reportes

## Costos Estimados (MVP)

### Mensual (uso moderado: 100 casos/mes)

- **Lambda**: $10-20
  - 100K invocaciones
  - 512MB, 30s promedio
  
- **DynamoDB**: $5-10
  - On-demand
  - 1M read units, 500K write units
  
- **S3**: $10-20
  - 100GB storage
  - 10K PUT, 50K GET
  
- **API Gateway**: $3.50
  - 1M requests
  
- **Bedrock**: $30-60
  - Claude Sonnet: $0.003/1K input tokens, $0.015/1K output tokens
  - 10M input tokens, 2M output tokens
  
- **Textract**: $15-30
  - 1K páginas
  - $1.50/1K páginas
  
- **Step Functions**: $2.50
  - 100 executions
  - 50 state transitions/execution
  
- **Cognito**: $0
  - <50K MAU gratis
  
- **Amplify**: $5-10
  - 10GB servido
  - 100 build minutes
  
- **CloudWatch**: $5-10
  - Logs, metrics, alarms

**Total**: $86-165/mes

### Producción (1000 casos/mes)

**Total estimado**: $500-1000/mes

## Disaster Recovery

### Backup

**DynamoDB**:
- Point-in-time recovery (PITR): Habilitado
- On-demand backups: Semanales

**S3**:
- Versioning: Habilitado
- Cross-region replication: Opcional

### RTO/RPO

- **RTO** (Recovery Time Objective): <1 hora
- **RPO** (Recovery Point Objective): <15 minutos

### Multi-Region

Para alta disponibilidad:
- DynamoDB Global Tables
- S3 Cross-Region Replication
- Route 53 failover
- CloudFront multi-origin
