#!/bin/bash
set -e

echo "Desplegando Step Functions..."

STEPFUNCTIONS_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${STACK_NAME}-stepfunctions-role"
AGENT_ID=$(cat /tmp/bedrock-agent-ids.json | grep -o '"agent_id": "[^"]*' | cut -d'"' -f4)
AGENT_ALIAS_ID=$(cat /tmp/bedrock-agent-ids.json | grep -o '"agent_alias_id": "[^"]*' | cut -d'"' -f4)

# Crear definición de Step Functions
cat > /tmp/workflow-definition.json <<EOF
{
  "Comment": "Workflow para procesamiento de estudio de títulos",
  "StartAt": "GetCaseDetails",
  "States": {
    "GetCaseDetails": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:getItem",
      "Parameters": {
        "TableName": "${STACK_NAME}-cases",
        "Key": {
          "case_id": {
            "S.$": "$.case_id"
          }
        }
      },
      "ResultPath": "$.caseData",
      "Next": "DetermineScope"
    },
    "DetermineScope": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.caseData.Item.scope.S",
          "StringEquals": "basic",
          "Next": "ProcessBasicScope"
        },
        {
          "Variable": "$.caseData.Item.scope.S",
          "StringEquals": "dd",
          "Next": "ProcessDDScope"
        }
      ],
      "Default": "ProcessBasicScope"
    },
    "ProcessBasicScope": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "Phase1_Reception",
          "States": {
            "Phase1_Reception": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Ejecutar Fase 1: Recepción y apertura del expediente"
              },
              "ResultPath": "$.phase1Result",
              "Next": "Phase2_Documents"
            },
            "Phase2_Documents": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Ejecutar Fase 2: Obtención y verificación de documentos"
              },
              "ResultPath": "$.phase2Result",
              "Next": "Phase3_Tradicion"
            },
            "Phase3_Tradicion": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Ejecutar Fase 3: Análisis de tradición (mínimo 10 años)"
              },
              "ResultPath": "$.phase3Result",
              "Next": "Gate3_Tradicion"
            },
            "Gate3_Tradicion": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Evaluar Gate 3: ¿La cadena de tradición es válida y completa?"
              },
              "ResultPath": "$.gate3Result",
              "Next": "CheckGate3"
            },
            "CheckGate3": {
              "Type": "Choice",
              "Choices": [
                {
                  "Variable": "$.gate3Result.decision",
                  "StringEquals": "NO_GO",
                  "Next": "FailWorkflow"
                }
              ],
              "Default": "Phase4_Gravamenes"
            },
            "Phase4_Gravamenes": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Ejecutar Fase 4: Análisis de limitaciones, gravámenes y embargos"
              },
              "ResultPath": "$.phase4Result",
              "Next": "Phase5_Tributario"
            },
            "Phase5_Tributario": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Ejecutar Fase 5: Análisis tributario (predial 5 años)"
              },
              "ResultPath": "$.phase5Result",
              "Next": "Phase6_Vendedor"
            },
            "Phase6_Vendedor": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Ejecutar Fase 6: Verificación del vendedor"
              },
              "ResultPath": "$.phase6Result",
              "End": true
            },
            "FailWorkflow": {
              "Type": "Fail",
              "Error": "GateRejection",
              "Cause": "Gate decision was NO_GO"
            }
          }
        }
      ],
      "Next": "ConsolidateResults"
    },
    "ProcessDDScope": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "DD_Phases1to6",
          "States": {
            "DD_Phases1to6": {
              "Type": "Pass",
              "Comment": "Ejecutar fases 1-6 igual que básico",
              "Next": "Phase7_Urbanistico"
            },
            "Phase7_Urbanistico": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Ejecutar Fase 7: Análisis urbanístico (POT, UPZ, licencias, PH)"
              },
              "ResultPath": "$.phase7Result",
              "Next": "Phase8_TributarioExhaustivo"
            },
            "Phase8_TributarioExhaustivo": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Ejecutar Fase 8: Análisis tributario exhaustivo"
              },
              "ResultPath": "$.phase8Result",
              "Next": "Phase9_VendedorExhaustivo"
            },
            "Phase9_VendedorExhaustivo": {
              "Type": "Task",
              "Resource": "arn:aws:states:::bedrock:invokeAgent",
              "Parameters": {
                "AgentId": "${AGENT_ID}",
                "AgentAliasId": "${AGENT_ALIAS_ID}",
                "SessionId.$": "$.case_id",
                "InputText": "Ejecutar Fase 9: Verificación exhaustiva del vendedor"
              },
              "ResultPath": "$.phase9Result",
              "End": true
            }
          }
        }
      ],
      "Next": "ConsolidateResults"
    },
    "ConsolidateResults": {
      "Type": "Task",
      "Resource": "arn:aws:states:::bedrock:invokeAgent",
      "Parameters": {
        "AgentId": "${AGENT_ID}",
        "AgentAliasId": "${AGENT_ALIAS_ID}",
        "SessionId.$": "$.case_id",
        "InputText": "Consolidar todos los hallazgos y generar reporte final con semáforo"
      },
      "ResultPath": "$.consolidatedResult",
      "Next": "UpdateCaseStatus"
    },
    "UpdateCaseStatus": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:updateItem",
      "Parameters": {
        "TableName": "${STACK_NAME}-cases",
        "Key": {
          "case_id": {
            "S.$": "$.case_id"
          }
        },
        "UpdateExpression": "SET #status = :status, updated_at = :updated_at",
        "ExpressionAttributeNames": {
          "#status": "status"
        },
        "ExpressionAttributeValues": {
          ":status": {
            "S": "completed"
          },
          ":updated_at": {
            "S.$": "$$.State.EnteredTime"
          }
        }
      },
      "End": true
    }
  }
}
EOF

# Crear state machine
STATE_MACHINE_ARN=$(aws stepfunctions create-state-machine \
    --name "${STACK_NAME}-workflow" \
    --definition file:///tmp/workflow-definition.json \
    --role-arn ${STEPFUNCTIONS_ROLE_ARN} \
    --type STANDARD \
    --query 'stateMachineArn' \
    --output text 2>/dev/null || \
aws stepfunctions list-state-machines \
    --query "stateMachines[?name=='${STACK_NAME}-workflow'].stateMachineArn | [0]" \
    --output text)

if [ "${STATE_MACHINE_ARN}" != "None" ] && [ -n "${STATE_MACHINE_ARN}" ]; then
    # Actualizar definición si ya existe
    aws stepfunctions update-state-machine \
        --state-machine-arn ${STATE_MACHINE_ARN} \
        --definition file:///tmp/workflow-definition.json \
        --role-arn ${STEPFUNCTIONS_ROLE_ARN} > /dev/null
fi

echo "State Machine ARN: ${STATE_MACHINE_ARN}"

# Guardar output
cat > /tmp/stepfunctions-outputs.json <<EOF
{
  "state_machine_arn": "${STATE_MACHINE_ARN}",
  "state_machine_name": "${STACK_NAME}-workflow"
}
EOF

echo "✓ Step Functions desplegado"
