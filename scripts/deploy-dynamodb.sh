#!/bin/bash
set -e

echo "Desplegando DynamoDB tables..."

KMS_KEY_ID=$(cat /tmp/kms-key-id.txt)

# Table: Cases
aws dynamodb create-table \
  --table-name ${STACK_NAME}-cases \
  --attribute-definitions \
    AttributeName=case_id,AttributeType=S \
    AttributeName=created_at,AttributeType=S \
  --key-schema \
    AttributeName=case_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId=${KMS_KEY_ID} \
  --global-secondary-indexes \
    "[{
      \"IndexName\": \"created_at-index\",
      \"KeySchema\": [{\"AttributeName\":\"created_at\",\"KeyType\":\"HASH\"}],
      \"Projection\": {\"ProjectionType\":\"ALL\"}
    }]" \
  --tags Key=Project,Value=${PROJECT_NAME} Key=Environment,Value=${ENVIRONMENT} \
  2>/dev/null || echo "Table cases already exists"

# Table: Documents
aws dynamodb create-table \
  --table-name ${STACK_NAME}-documents \
  --attribute-definitions \
    AttributeName=doc_id,AttributeType=S \
    AttributeName=case_id,AttributeType=S \
  --key-schema \
    AttributeName=doc_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId=${KMS_KEY_ID} \
  --global-secondary-indexes \
    "[{
      \"IndexName\": \"case_id-index\",
      \"KeySchema\": [{\"AttributeName\":\"case_id\",\"KeyType\":\"HASH\"}],
      \"Projection\": {\"ProjectionType\":\"ALL\"}
    }]" \
  --tags Key=Project,Value=${PROJECT_NAME} Key=Environment,Value=${ENVIRONMENT} \
  2>/dev/null || echo "Table documents already exists"

# Table: Extractions
aws dynamodb create-table \
  --table-name ${STACK_NAME}-extractions \
  --attribute-definitions \
    AttributeName=case_id,AttributeType=S \
    AttributeName=doc_page,AttributeType=S \
  --key-schema \
    AttributeName=case_id,KeyType=HASH \
    AttributeName=doc_page,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId=${KMS_KEY_ID} \
  --tags Key=Project,Value=${PROJECT_NAME} Key=Environment,Value=${ENVIRONMENT} \
  2>/dev/null || echo "Table extractions already exists"

# Table: Findings
aws dynamodb create-table \
  --table-name ${STACK_NAME}-findings \
  --attribute-definitions \
    AttributeName=case_id,AttributeType=S \
    AttributeName=phase_finding_id,AttributeType=S \
  --key-schema \
    AttributeName=case_id,KeyType=HASH \
    AttributeName=phase_finding_id,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId=${KMS_KEY_ID} \
  --tags Key=Project,Value=${PROJECT_NAME} Key=Environment,Value=${ENVIRONMENT} \
  2>/dev/null || echo "Table findings already exists"

# Table: Gates
aws dynamodb create-table \
  --table-name ${STACK_NAME}-gates \
  --attribute-definitions \
    AttributeName=case_id,AttributeType=S \
    AttributeName=gate_id,AttributeType=S \
  --key-schema \
    AttributeName=case_id,KeyType=HASH \
    AttributeName=gate_id,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId=${KMS_KEY_ID} \
  --tags Key=Project,Value=${PROJECT_NAME} Key=Environment,Value=${ENVIRONMENT} \
  2>/dev/null || echo "Table gates already exists"

# Table: AuditEvents
aws dynamodb create-table \
  --table-name ${STACK_NAME}-audit-events \
  --attribute-definitions \
    AttributeName=case_id,AttributeType=S \
    AttributeName=ts_event_id,AttributeType=S \
  --key-schema \
    AttributeName=case_id,KeyType=HASH \
    AttributeName=ts_event_id,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId=${KMS_KEY_ID} \
  --tags Key=Project,Value=${PROJECT_NAME} Key=Environment,Value=${ENVIRONMENT} \
  2>/dev/null || echo "Table audit-events already exists"

# Esperar a que las tablas estén activas
echo "Esperando a que las tablas estén activas..."
for table in cases documents extractions findings gates audit-events; do
  aws dynamodb wait table-exists --table-name ${STACK_NAME}-${table}
done

echo "✓ DynamoDB tables creadas"
