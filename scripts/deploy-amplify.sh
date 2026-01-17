#!/bin/bash
set -e

echo "Desplegando Amplify..."

# Leer outputs de API
API_ENDPOINT=$(cat /tmp/api-outputs.json | grep -o '"api_endpoint": "[^"]*' | cut -d'"' -f4)
USER_POOL_ID=$(cat /tmp/api-outputs.json | grep -o '"user_pool_id": "[^"]*' | cut -d'"' -f4)
CLIENT_ID=$(cat /tmp/api-outputs.json | grep -o '"client_id": "[^"]*' | cut -d'"' -f4)

# Crear configuración de Amplify
mkdir -p frontend/src
cat > frontend/src/aws-exports.js <<EOF
const awsconfig = {
  aws_project_region: '${AWS_REGION}',
  aws_cognito_region: '${AWS_REGION}',
  aws_user_pools_id: '${USER_POOL_ID}',
  aws_user_pools_web_client_id: '${CLIENT_ID}',
  oauth: {},
  aws_cloud_logic_custom: [
    {
      name: 'EstudioTitulosAPI',
      endpoint: '${API_ENDPOINT}',
      region: '${AWS_REGION}'
    }
  ]
};

export default awsconfig;
EOF

# Crear package.json básico
cat > frontend/package.json <<EOF
{
  "name": "estudio-titulos-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "export": "next export"
  },
  "dependencies": {
    "next": "^14.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "aws-amplify": "^6.0.0",
    "@aws-amplify/ui-react": "^6.0.0"
  }
}
EOF

# Crear página principal básica
mkdir -p frontend/pages
cat > frontend/pages/index.js <<'EOF'
import { Amplify } from 'aws-amplify';
import { Authenticator } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';
import awsconfig from '../src/aws-exports';

Amplify.configure(awsconfig);

export default function Home() {
  return (
    <Authenticator>
      {({ signOut, user }) => (
        <main style={{ padding: '2rem' }}>
          <h1>Plataforma de Estudio de Títulos</h1>
          <p>Bienvenido, {user.username}</p>
          <button onClick={signOut}>Cerrar Sesión</button>
          
          <div style={{ marginTop: '2rem' }}>
            <h2>Casos</h2>
            <p>Gestión de expedientes de estudio de títulos</p>
            {/* Aquí irá la interfaz de gestión de casos */}
          </div>
        </main>
      )}
    </Authenticator>
  );
}
EOF

# Crear next.config.js
cat > frontend/next.config.js <<EOF
module.exports = {
  output: 'export',
  distDir: 'out',
  images: {
    unoptimized: true
  }
}
EOF

# Verificar si existe repositorio Git
if [ ! -d ".git" ]; then
    echo "Inicializando repositorio Git..."
    git init
    git add .
    git commit -m "Initial commit"
fi

# Crear app en Amplify
APP_ID=$(aws amplify create-app \
    --name "${STACK_NAME}-frontend" \
    --description "Frontend for Estudio de Títulos platform" \
    --repository "https://github.com/placeholder/repo" \
    --platform WEB \
    --environment-variables \
        AMPLIFY_MONOREPO_APP_ROOT=frontend \
    --custom-rules \
        '[{"source":"/<*>","target":"/index.html","status":"404-200"}]' \
    --query 'app.appId' \
    --output text 2>/dev/null || \
aws amplify list-apps \
    --query "apps[?name=='${STACK_NAME}-frontend'].appId | [0]" \
    --output text)

echo "Amplify App ID: ${APP_ID}"

# Crear branch
BRANCH_NAME="main"
aws amplify create-branch \
    --app-id ${APP_ID} \
    --branch-name ${BRANCH_NAME} \
    --enable-auto-build \
    --framework "Next.js - SSG" \
    2>/dev/null || echo "Branch already exists"

# Configurar build settings
cat > /tmp/amplify-build-spec.yml <<EOF
version: 1
frontend:
  phases:
    preBuild:
      commands:
        - cd frontend
        - npm ci
    build:
      commands:
        - npm run build
  artifacts:
    baseDirectory: frontend/out
    files:
      - '**/*'
  cache:
    paths:
      - frontend/node_modules/**/*
EOF

aws amplify update-app \
    --app-id ${APP_ID} \
    --build-spec file:///tmp/amplify-build-spec.yml > /dev/null

# Obtener URL de la app
APP_URL="https://${BRANCH_NAME}.${APP_ID}.amplifyapp.com"

# Guardar outputs
cat > /tmp/amplify-outputs.json <<EOF
{
  "app_id": "${APP_ID}",
  "app_url": "${APP_URL}",
  "branch": "${BRANCH_NAME}"
}
EOF

echo "✓ Amplify configurado"
echo "  App ID: ${APP_ID}"
echo "  URL: ${APP_URL}"
echo ""
echo "NOTA: Para desplegar el frontend:"
echo "  1. Conecta tu repositorio Git en la consola de Amplify"
echo "  2. O usa: aws amplify start-job --app-id ${APP_ID} --branch-name ${BRANCH_NAME} --job-type RELEASE"
