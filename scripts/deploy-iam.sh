#!/bin/bash
set -e

echo "Desplegando IAM roles y policies..."

# Lambda Execution Role
cat > /tmp/lambda-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name ${STACK_NAME}-lambda-execution-role \
  --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
  --description "Lambda execution role for ${STACK_NAME}" \
  2>/dev/null || echo "Role already exists"

# Lambda Policy
cat > /tmp/lambda-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${AWS_REGION}:${AWS_ACCOUNT_ID}:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${STACK_NAME}-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${STACK_NAME}-*",
        "arn:aws:s3:::${STACK_NAME}-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "textract:StartDocumentAnalysis",
        "textract:GetDocumentAnalysis",
        "textract:StartDocumentTextDetection",
        "textract:GetDocumentTextDetection"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeAgent"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "arn:aws:kms:${AWS_REGION}:${AWS_ACCOUNT_ID}:key/*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name ${STACK_NAME}-lambda-execution-role \
  --policy-name ${STACK_NAME}-lambda-policy \
  --policy-document file:///tmp/lambda-policy.json

# Bedrock Agent Role
cat > /tmp/bedrock-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "bedrock.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name ${STACK_NAME}-bedrock-agent-role \
  --assume-role-policy-document file:///tmp/bedrock-trust-policy.json \
  --description "Bedrock Agent role for ${STACK_NAME}" \
  2>/dev/null || echo "Role already exists"

cat > /tmp/bedrock-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${STACK_NAME}-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${STACK_NAME}-*",
        "arn:aws:s3:::${STACK_NAME}-*/*"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name ${STACK_NAME}-bedrock-agent-role \
  --policy-name ${STACK_NAME}-bedrock-policy \
  --policy-document file:///tmp/bedrock-policy.json

# Step Functions Role
cat > /tmp/stepfunctions-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "states.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name ${STACK_NAME}-stepfunctions-role \
  --assume-role-policy-document file:///tmp/stepfunctions-trust-policy.json \
  --description "Step Functions role for ${STACK_NAME}" \
  2>/dev/null || echo "Role already exists"

cat > /tmp/stepfunctions-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:InvokeFunction"
      ],
      "Resource": "arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${STACK_NAME}-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeAgent"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${STACK_NAME}-*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name ${STACK_NAME}-stepfunctions-role \
  --policy-name ${STACK_NAME}-stepfunctions-policy \
  --policy-document file:///tmp/stepfunctions-policy.json

# Esperar a que los roles estén disponibles
echo "Esperando propagación de roles IAM..."
sleep 10

echo "✓ IAM roles creados"
