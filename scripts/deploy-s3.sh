#!/bin/bash
set -e

echo "Desplegando S3 buckets..."

# Crear KMS key para encriptación
KMS_KEY_ID=$(aws kms create-key \
  --description "${STACK_NAME} encryption key" \
  --query 'KeyMetadata.KeyId' \
  --output text 2>/dev/null || aws kms list-keys --query 'Keys[0].KeyId' --output text)

aws kms create-alias \
  --alias-name alias/${STACK_NAME}-key \
  --target-key-id ${KMS_KEY_ID} 2>/dev/null || echo "Alias already exists"

echo "KMS Key ID: ${KMS_KEY_ID}"

# Bucket para documentos raw
aws s3 mb s3://${STACK_NAME}-raw-docs --region ${AWS_REGION} 2>/dev/null || echo "Bucket exists"
aws s3api put-bucket-versioning \
  --bucket ${STACK_NAME}-raw-docs \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket ${STACK_NAME}-raw-docs \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "'${KMS_KEY_ID}'"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Bucket para documentos procesados
aws s3 mb s3://${STACK_NAME}-processed-docs --region ${AWS_REGION} 2>/dev/null || echo "Bucket exists"
aws s3api put-bucket-versioning \
  --bucket ${STACK_NAME}-processed-docs \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket ${STACK_NAME}-processed-docs \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "'${KMS_KEY_ID}'"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Bucket para reportes
aws s3 mb s3://${STACK_NAME}-reports --region ${AWS_REGION} 2>/dev/null || echo "Bucket exists"
aws s3api put-bucket-versioning \
  --bucket ${STACK_NAME}-reports \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket ${STACK_NAME}-reports \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "'${KMS_KEY_ID}'"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Bucket para Knowledge Base
aws s3 mb s3://${STACK_NAME}-knowledge-base --region ${AWS_REGION} 2>/dev/null || echo "Bucket exists"
aws s3api put-bucket-encryption \
  --bucket ${STACK_NAME}-knowledge-base \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "'${KMS_KEY_ID}'"
      },
      "BucketKeyEnabled": true
    }]
  }'

# Block public access en todos los buckets
for bucket in raw-docs processed-docs reports knowledge-base; do
  aws s3api put-public-access-block \
    --bucket ${STACK_NAME}-${bucket} \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
done

# Guardar KMS Key ID para otros scripts
echo ${KMS_KEY_ID} > /tmp/kms-key-id.txt

echo "✓ S3 buckets creados y configurados"
