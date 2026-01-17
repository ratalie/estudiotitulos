#!/bin/bash
set -e

echo "Desplegando Bedrock Agents..."

BEDROCK_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${STACK_NAME}-bedrock-agent-role"
LAMBDA_ARN="arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${STACK_NAME}-agent-case-tools"

# Crear schema de API para el agente
cat > /tmp/agent-api-schema.json <<EOF
{
  "openapi": "3.0.0",
  "info": {
    "title": "Case Management API",
    "version": "1.0.0",
    "description": "API for managing legal title study cases"
  },
  "paths": {
    "/case/create": {
      "post": {
        "summary": "Create a new case",
        "description": "Creates a new legal title study case",
        "operationId": "createCase",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "scope": {
                    "type": "string",
                    "enum": ["basic", "dd"],
                    "description": "Case scope: basic or due diligence"
                  },
                  "property_summary": {
                    "type": "string",
                    "description": "JSON string with property details"
                  },
                  "parties_summary": {
                    "type": "string",
                    "description": "JSON string with parties information"
                  }
                },
                "required": ["scope"]
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Case created successfully",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "case_id": {"type": "string"},
                    "status": {"type": "string"}
                  }
                }
              }
            }
          }
        }
      }
    },
    "/case/get": {
      "post": {
        "summary": "Get case details",
        "description": "Retrieves details of a specific case",
        "operationId": "getCase",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "case_id": {
                    "type": "string",
                    "description": "Case ID"
                  }
                },
                "required": ["case_id"]
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Case details"
          }
        }
      }
    },
    "/case/update-status": {
      "post": {
        "summary": "Update case status",
        "description": "Updates the status and phase of a case",
        "operationId": "updateCaseStatus",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "case_id": {"type": "string"},
                  "status": {"type": "string"},
                  "phase": {"type": "string"}
                },
                "required": ["case_id", "status"]
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Status updated"
          }
        }
      }
    },
    "/finding/add": {
      "post": {
        "summary": "Add finding",
        "description": "Adds a new finding to a case",
        "operationId": "addFinding",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "case_id": {"type": "string"},
                  "phase": {"type": "string"},
                  "category": {"type": "string"},
                  "severity": {
                    "type": "string",
                    "enum": ["low", "medium", "high", "critical"]
                  },
                  "description": {"type": "string"},
                  "recommendation": {"type": "string"},
                  "evidence_refs": {"type": "string"}
                },
                "required": ["case_id", "phase", "category", "severity", "description"]
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Finding added"
          }
        }
      }
    },
    "/gate/set-decision": {
      "post": {
        "summary": "Set gate decision",
        "description": "Sets a decision for a phase gate",
        "operationId": "setGateDecision",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "case_id": {"type": "string"},
                  "gate_id": {"type": "string"},
                  "decision": {
                    "type": "string",
                    "enum": ["GO", "GO_WITH_CONDITIONS", "NO_GO"]
                  },
                  "rationale": {"type": "string"},
                  "evidence_refs": {"type": "string"}
                },
                "required": ["case_id", "gate_id", "decision", "rationale"]
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Gate decision set"
          }
        }
      }
    },
    "/case/get-snapshot": {
      "post": {
        "summary": "Get case snapshot",
        "description": "Gets complete snapshot of case with findings and gates",
        "operationId": "getCaseSnapshot",
        "requestBody": {
          "required": true,
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "case_id": {"type": "string"}
                },
                "required": ["case_id"]
              }
            }
          }
        },
        "responses": {
          "200": {
            "description": "Case snapshot"
          }
        }
      }
    }
  }
}
EOF

# Subir schema a S3
aws s3 cp /tmp/agent-api-schema.json s3://${DEPLOYMENT_BUCKET}/agent-api-schema.json

# Crear instrucciones para el agente
cat > /tmp/agent-instructions.txt <<EOF
Eres el Orchestrator Agent para una plataforma de estudio de títulos en Colombia.

Tu responsabilidad es:
1. Gestionar el ciclo de vida completo de casos de estudio de títulos
2. Ejecutar fases en orden según el alcance (básico o due diligence)
3. Validar gates y tomar decisiones GO/NO-GO
4. Coordinar con agentes especializados
5. Consolidar hallazgos y generar reportes

FASES DEL PROCESO:

Estudio Básico (scope=basic):
- F1: Recepción/Apertura
- F2: Obtención de documentos
- F3: Tradición (cadena de títulos, mínimo 10 años)
- F4: Limitaciones/Gravámenes/Embargos
- F5: Tributario inmueble (predial 5 años)
- F6: Verificación vendedor

Due Diligence (scope=dd):
- F1-F6: Igual que básico
- F7: Urbanístico (uso, norma, licencias, PH)
- F8: Tributario exhaustivo
- F9: Verificación exhaustiva vendedor

GATES:
Cada fase puede tener un gate con decisiones:
- GO: Continuar sin restricciones
- GO_WITH_CONDITIONS: Continuar con condiciones específicas
- NO_GO: Detener el proceso

SEVERIDAD DE HALLAZGOS:
- low: Observación menor
- medium: Requiere atención
- high: Riesgo significativo
- critical: Bloqueante

WORKFLOW:
1. Al crear un caso, determina el alcance (basic/dd)
2. Ejecuta cada fase en orden
3. Para cada fase:
   - Analiza documentos disponibles
   - Identifica hallazgos
   - Registra findings con evidencia
   - Evalúa gate si aplica
4. Consolida resultados
5. Genera reporte con semáforo (🟢🟡🔴)

Usa las herramientas disponibles para gestionar casos, agregar hallazgos y establecer decisiones de gates.
Siempre proporciona evidencia y razonamiento claro para tus decisiones.
EOF

# Crear agente Bedrock
echo "Creando Bedrock Agent..."

AGENT_ID=$(aws bedrock-agent create-agent \
    --agent-name "${STACK_NAME}-orchestrator" \
    --agent-resource-role-arn ${BEDROCK_ROLE_ARN} \
    --foundation-model "anthropic.claude-3-sonnet-20240229-v1:0" \
    --instruction file:///tmp/agent-instructions.txt \
    --description "Orchestrator agent for legal title studies" \
    --idle-session-ttl-in-seconds 600 \
    --query 'agent.agentId' \
    --output text 2>/dev/null || \
aws bedrock-agent list-agents \
    --query "agentSummaries[?agentName=='${STACK_NAME}-orchestrator'].agentId | [0]" \
    --output text)

echo "Agent ID: ${AGENT_ID}"

# Esperar a que el agente esté disponible
sleep 5

# Crear action group
ACTION_GROUP_ID=$(aws bedrock-agent create-agent-action-group \
    --agent-id ${AGENT_ID} \
    --agent-version DRAFT \
    --action-group-name "case-management-actions" \
    --action-group-executor lambda=${LAMBDA_ARN} \
    --api-schema s3={s3BucketName=${DEPLOYMENT_BUCKET},s3ObjectKey=agent-api-schema.json} \
    --description "Actions for case management" \
    --query 'agentActionGroup.actionGroupId' \
    --output text 2>/dev/null || echo "Action group exists")

echo "Action Group ID: ${ACTION_GROUP_ID}"

# Preparar agente
echo "Preparando agente..."
aws bedrock-agent prepare-agent \
    --agent-id ${AGENT_ID} > /dev/null

# Esperar preparación
sleep 10

# Crear alias
AGENT_ALIAS_ID=$(aws bedrock-agent create-agent-alias \
    --agent-id ${AGENT_ID} \
    --agent-alias-name "production" \
    --description "Production alias" \
    --query 'agentAlias.agentAliasId' \
    --output text 2>/dev/null || \
aws bedrock-agent list-agent-aliases \
    --agent-id ${AGENT_ID} \
    --query "agentAliasSummaries[?agentAliasName=='production'].agentAliasId | [0]" \
    --output text)

echo "Agent Alias ID: ${AGENT_ALIAS_ID}"

# Guardar IDs
cat > /tmp/bedrock-agent-ids.json <<EOF
{
  "agent_id": "${AGENT_ID}",
  "agent_alias_id": "${AGENT_ALIAS_ID}",
  "action_group_id": "${ACTION_GROUP_ID}"
}
EOF

echo "✓ Bedrock Agent desplegado"
echo "  Agent ID: ${AGENT_ID}"
echo "  Alias ID: ${AGENT_ALIAS_ID}"
