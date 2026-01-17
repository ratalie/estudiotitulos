# Setup en Windows - Plataforma Estudio de Títulos

## 🪟 Guía Específica para Windows

### Prerrequisitos

#### 1. Instalar AWS CLI

```powershell
# Descargar instalador
# https://awscli.amazonaws.com/AWSCLIV2.msi

# O con Chocolatey
choco install awscli

# Verificar
aws --version
```

#### 2. Configurar AWS CLI

```powershell
aws configure
# AWS Access Key ID: [tu-access-key]
# AWS Secret Access Key: [tu-secret-key]
# Default region name: us-east-1
# Default output format: json
```

#### 3. Instalar Python 3.11+

```powershell
# Descargar desde python.org
# https://www.python.org/downloads/

# O con Chocolatey
choco install python

# Verificar
python --version
pip --version
```

#### 4. Instalar Git Bash (Recomendado)

```powershell
# Descargar desde git-scm.com
# https://git-scm.com/download/win

# O con Chocolatey
choco install git
```

## 🚀 Deployment en Windows

### Opción 1: Usar Git Bash (Recomendado)

```bash
# Abrir Git Bash
# Navegar al proyecto
cd /c/Users/natal/estudiotitulos/estudiotitulos

# Configurar variables
export AWS_REGION=us-east-1
export ENVIRONMENT=dev

# Dar permisos
chmod +x deploy.sh scripts/*.sh

# Ejecutar deployment
./deploy.sh
```

### Opción 2: Usar PowerShell

```powershell
# Configurar variables
$env:AWS_REGION = "us-east-1"
$env:ENVIRONMENT = "dev"
$env:PROJECT_NAME = "estudio-titulos"
$env:STACK_NAME = "$env:PROJECT_NAME-$env:ENVIRONMENT"

# Obtener Account ID
$env:AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

# Ejecutar scripts uno por uno
bash scripts/deploy-iam.sh
bash scripts/deploy-s3.sh
bash scripts/deploy-dynamodb.sh
bash scripts/deploy-lambdas.sh
bash scripts/deploy-api.sh
bash scripts/deploy-bedrock-agents.sh
bash scripts/deploy-stepfunctions.sh
bash scripts/deploy-amplify.sh
bash scripts/save-outputs.sh
```

### Opción 3: Usar WSL (Windows Subsystem for Linux)

```bash
# Instalar WSL
wsl --install

# Abrir Ubuntu
wsl

# Instalar AWS CLI en WSL
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configurar
aws configure

# Navegar al proyecto (desde Windows)
cd /mnt/c/Users/natal/estudiotitulos/estudiotitulos

# Ejecutar deployment
export AWS_REGION=us-east-1
export ENVIRONMENT=dev
./deploy.sh
```

## 🔧 Troubleshooting Windows

### Error: "bash: command not found"

**Solución**: Instalar Git Bash o usar WSL

```powershell
# Instalar Git Bash
choco install git

# O usar WSL
wsl --install
```

### Error: "Permission denied"

**Solución**: Ejecutar como Administrador o usar Git Bash

```bash
# En Git Bash
chmod +x deploy.sh scripts/*.sh
./deploy.sh
```

### Error: "Line endings CRLF"

**Solución**: Configurar Git para manejar line endings

```bash
# Configurar Git
git config --global core.autocrlf true

# O convertir archivos
dos2unix deploy.sh scripts/*.sh
```

### Error: "Python not found"

**Solución**: Agregar Python al PATH

```powershell
# Agregar a PATH (reemplaza con tu ruta)
$env:Path += ";C:\Python311;C:\Python311\Scripts"

# O reinstalar Python marcando "Add to PATH"
```

### Error: "AWS credentials not configured"

**Solución**: Configurar credenciales

```powershell
aws configure

# O crear archivo manualmente
# C:\Users\[tu-usuario]\.aws\credentials
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY

# C:\Users\[tu-usuario]\.aws\config
[default]
region = us-east-1
output = json
```

## 📝 Comandos Útiles en Windows

### PowerShell

```powershell
# Ver variables de entorno
Get-ChildItem Env:

# Establecer variable
$env:AWS_REGION = "us-east-1"

# Ver logs
aws logs tail /aws/lambda/$env:STACK_NAME-api-cases --follow

# Listar recursos
aws dynamodb list-tables
aws s3 ls
aws lambda list-functions
```

### Git Bash

```bash
# Ver variables
env | grep AWS

# Establecer variable
export AWS_REGION=us-east-1

# Ver logs
aws logs tail /aws/lambda/${STACK_NAME}-api-cases --follow

# Listar recursos
aws dynamodb list-tables
aws s3 ls
aws lambda list-functions
```

## 🧪 Probar en Windows

### PowerShell

```powershell
# Cargar variables
$outputs = Get-Content outputs/dev.json | ConvertFrom-Json
$env:API_ENDPOINT = $outputs.api.api_endpoint
$env:USER_POOL_ID = $outputs.api.user_pool_id
$env:CLIENT_ID = $outputs.api.client_id

# Crear usuario
aws cognito-idp admin-create-user `
  --user-pool-id $env:USER_POOL_ID `
  --username analista@test.com `
  --user-attributes Name=email,Value=analista@test.com Name=email_verified,Value=true `
  --temporary-password "TempPass123!" `
  --message-action SUPPRESS

# Obtener token
$auth = aws cognito-idp admin-initiate-auth `
  --user-pool-id $env:USER_POOL_ID `
  --client-id $env:CLIENT_ID `
  --auth-flow ADMIN_NO_SRP_AUTH `
  --auth-parameters USERNAME=analista@test.com,PASSWORD=YourNewPassword123! `
  | ConvertFrom-Json

$token = $auth.AuthenticationResult.IdToken

# Crear caso
$body = @{
  scope = "basic"
  property_summary = @{
    matricula = "050-12345"
    direccion = "Calle 123 #45-67"
  }
} | ConvertTo-Json

Invoke-RestMethod -Uri "$env:API_ENDPOINT/cases" `
  -Method POST `
  -Headers @{Authorization="Bearer $token"} `
  -ContentType "application/json" `
  -Body $body
```

### Git Bash / WSL

```bash
# Cargar variables
source outputs/dev.env

# Crear usuario
aws cognito-idp admin-create-user \
  --user-pool-id ${USER_POOL_ID} \
  --username analista@test.com \
  --user-attributes Name=email,Value=analista@test.com Name=email_verified,Value=true \
  --temporary-password TempPass123! \
  --message-action SUPPRESS

# Obtener token
TOKEN=$(aws cognito-idp admin-initiate-auth \
  --user-pool-id ${USER_POOL_ID} \
  --client-id ${CLIENT_ID} \
  --auth-flow ADMIN_NO_SRP_AUTH \
  --auth-parameters USERNAME=analista@test.com,PASSWORD=YourNewPassword123! \
  --query 'AuthenticationResult.IdToken' \
  --output text)

# Crear caso
curl -X POST ${API_ENDPOINT}/cases \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "scope": "basic",
    "property_summary": {
      "matricula": "050-12345",
      "direccion": "Calle 123 #45-67"
    }
  }'
```

## 🧹 Limpieza en Windows

### PowerShell

```powershell
# Configurar variables
$env:AWS_REGION = "us-east-1"
$env:ENVIRONMENT = "dev"
$env:PROJECT_NAME = "estudio-titulos"
$env:STACK_NAME = "$env:PROJECT_NAME-$env:ENVIRONMENT"
$env:AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

# Ejecutar limpieza
bash scripts/cleanup.sh
```

### Git Bash

```bash
export AWS_REGION=us-east-1
export ENVIRONMENT=dev
./scripts/cleanup.sh
```

## 💡 Tips para Windows

### 1. Usar Terminal Windows

```powershell
# Instalar Windows Terminal (recomendado)
winget install Microsoft.WindowsTerminal

# O desde Microsoft Store
```

### 2. Configurar Git Bash como Default

En Windows Terminal:
1. Settings → Default Profile → Git Bash
2. Restart terminal

### 3. Alias Útiles

```bash
# Agregar a ~/.bashrc (Git Bash)
alias awsl='aws logs tail'
alias awsd='aws dynamodb'
alias awss='aws s3'
alias awslambda='aws lambda'

# Recargar
source ~/.bashrc
```

### 4. Usar Visual Studio Code

```powershell
# Instalar VS Code
winget install Microsoft.VisualStudioCode

# Abrir proyecto
code .

# Instalar extensiones recomendadas:
# - AWS Toolkit
# - Python
# - GitLens
```

## 📚 Recursos Adicionales

- [AWS CLI en Windows](https://docs.aws.amazon.com/cli/latest/userguide/install-windows.html)
- [Git Bash](https://git-scm.com/download/win)
- [WSL](https://docs.microsoft.com/en-us/windows/wsl/install)
- [Windows Terminal](https://aka.ms/terminal)
- [Chocolatey](https://chocolatey.org/)

## ✅ Checklist de Setup

- [ ] AWS CLI instalado
- [ ] AWS CLI configurado (credentials)
- [ ] Python 3.11+ instalado
- [ ] Git instalado
- [ ] Git Bash o WSL disponible
- [ ] Repositorio clonado
- [ ] Variables de entorno configuradas
- [ ] Permisos de ejecución en scripts
- [ ] Deployment ejecutado exitosamente
- [ ] Outputs verificados

## 🎉 ¡Listo!

Tu plataforma está funcionando en AWS desde Windows.

Para más información, ver:
- [QUICKSTART.md](QUICKSTART.md)
- [DEPLOYMENT.md](DEPLOYMENT.md)
