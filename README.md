# CloudMentor Prod

CloudMentor is a teaching-friendly AI learning assistant built with React, AWS Lambda, API Gateway, S3, DynamoDB, CloudWatch, and GitHub Actions CI/CD.

This **prod** version is designed for this deployment model:

```text
GitHub push to main
  -> GitHub Actions
  -> AWS SAM deploys backend infrastructure
  -> Lambda + API Gateway + S3 + DynamoDB + CloudWatch are created/updated
  -> GitHub Actions reads the real API Gateway URL
  -> React frontend is built with that API URL
  -> Full source code is pushed to EC2
  -> React dist files are published to Nginx on EC2
  -> Students open the app from the EC2 public IP
```

Production URL pattern:

```text
Frontend: http://YOUR_EC2_PUBLIC_IP
Backend:  https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com
```

---

## 1. Technology stack

### Frontend

- React
- Vite
- JavaScript / JSX
- CSS glassmorphism UI
- Nginx on EC2 for static hosting

### Backend

- AWS Lambda, Node.js 22 runtime
- Amazon API Gateway HTTP API
- Amazon S3 for uploaded study materials
- Amazon DynamoDB for history and progress
- Amazon CloudWatch Logs for Lambda logs
- OpenAI API as the AI brain
- Mock AI mode for classroom demos without OpenAI billing

### DevOps

- GitHub Actions
- AWS SAM
- AWS CloudFormation
- AWS CLI
- EC2 + SSH + rsync

---

## 2. Final production architecture

```text
Student Browser
  -> http://EC2_PUBLIC_IP
  -> Nginx serves React static files
  -> React calls VITE_API_BASE_URL
  -> API Gateway
  -> Lambda
  -> OpenAI API
  -> S3 for uploaded files
  -> DynamoDB for history/progress
  -> CloudWatch for logs
```

Important: in production, **EC2 does not run the backend Lambda locally**. EC2 only serves the frontend. The backend runs as real AWS Lambda behind API Gateway.

---

## 3. Project structure

```text
cloudmentor-serverless-prod/
├── .github/workflows/deploy-prod.yml
├── backend/
│   ├── template.yaml
│   ├── package.json
│   ├── env.local.example.json
│   ├── env.ec2.example.json
│   ├── env.production.example.json
│   └── src/
│       ├── app.mjs
│       └── prompts.mjs
├── frontend/
│   ├── .env.example
│   ├── .env.production.example
│   ├── package.json
│   └── src/
├── scripts/
│   ├── prod-ec2-bootstrap.sh
│   ├── ec2-bootstrap.sh
│   ├── ec2-deploy.sh
│   └── create-ec2-aws-resources.sh
└── README.md
```

---

## 4. Local development first

Use this before production deployment so students understand the app locally.

### 4.1 Backend local setup

```bash
cd cloudmentor-serverless-prod/backend
cp env.local.example.json env.json
npm install
sam build
sam local start-api --env-vars env.json
```

Local backend:

```text
http://localhost:3000
```

Test:

```bash
curl http://localhost:3000/health
```

For free classroom testing, use mock mode in `backend/env.json`:

```json
{
  "CloudMentorFunction": {
    "AI_MODE": "mock",
    "OPENAI_API_KEY": "",
    "OPENAI_MODEL": "gpt-4.1-mini",
    "TABLE_NAME": "",
    "MATERIALS_BUCKET": "",
    "CORS_ORIGIN": "*",
    "STORAGE_MODE": "local",
    "LOCAL_DEV": "true"
  }
}
```

### 4.2 Frontend local setup

Open another terminal:

```bash
cd cloudmentor-serverless-prod/frontend
cp .env.example .env
npm install
npm run dev
```

Local frontend:

```text
http://localhost:5173
```

For local frontend, `frontend/.env` should contain:

```env
VITE_API_BASE_URL=http://localhost:3000
```

---

## 5. Create an OpenAI API key

1. Go to the OpenAI Platform API key page.
2. Create a new secret key.
3. Save it somewhere safe.
4. For local testing, put it only in `backend/env.json` if `AI_MODE=openai`.
5. For production, put it in GitHub Actions secret `OPENAI_API_KEY`.

Never commit the API key to GitHub.

Use `AI_MODE=mock` if you want to deploy the app without OpenAI billing while teaching.

---

## 6. Create the EC2 machine

Recommended for class:

```text
AMI: Ubuntu 24.04 LTS or Ubuntu 22.04 LTS
Instance type: t2.micro or t3.micro for demo
Storage: 10 GB or more
Key pair: create/download a .pem file
```

Security group inbound rules:

```text
SSH  22  Your IP only
HTTP 80  0.0.0.0/0
```

After creating EC2, note:

```text
EC2 public IPv4 address
EC2 SSH username, usually ubuntu
Private key .pem file content
```

You do not need to manually install Nginx if you use the GitHub Actions workflow. The workflow runs `scripts/prod-ec2-bootstrap.sh` over SSH and installs/configures Nginx automatically.

Manual SSH test:

```bash
chmod 600 cloudmentor-key.pem
ssh -i cloudmentor-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

---

## 7. AWS IAM for GitHub Actions

GitHub Actions needs permission to deploy the SAM backend.

For a student/demo project, the easiest option is to create an IAM user with programmatic access and attach enough permissions for:

```text
CloudFormation
Lambda
API Gateway
S3
DynamoDB
CloudWatch Logs
IAM role creation for Lambda
AWS SAM deployment bucket creation
```

For professional production, use GitHub OIDC and an assumable IAM role instead of long-lived access keys.

For classroom simplicity, start with these GitHub secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
```

---

## 8. GitHub repository secrets

Go to:

```text
GitHub repository
  -> Settings
  -> Secrets and variables
  -> Actions
  -> New repository secret
```

Create these secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
SAM_STACK_NAME
OPENAI_API_KEY
OPENAI_MODEL
AI_MODE
CORS_ORIGIN
EC2_HOST
EC2_USER
EC2_SSH_KEY
EC2_APP_DIR
```

Example values:

```text
AWS_REGION=ap-southeast-1
SAM_STACK_NAME=cloudmentor-prod
OPENAI_MODEL=gpt-4.1-mini
AI_MODE=openai
CORS_ORIGIN=http://YOUR_EC2_PUBLIC_IP
EC2_HOST=YOUR_EC2_PUBLIC_IP
EC2_USER=ubuntu
EC2_APP_DIR=/opt/cloudmentor
```

For `EC2_SSH_KEY`, paste the full private key content, including:

```text
-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----
```

or:

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

### Demo deployment without OpenAI billing

Use:

```text
AI_MODE=mock
OPENAI_API_KEY=
```

The workflow can deploy mock mode without a real OpenAI key.

### Real AI deployment

Use:

```text
AI_MODE=openai
OPENAI_API_KEY=sk-proj-your-real-key
```

---

## 9. What GitHub Actions does

The production workflow is here:

```text
.github/workflows/deploy-prod.yml
```

When you push to `main`, it performs these steps:

```text
1. Checks out the repository
2. Sets up Node.js 22
3. Configures AWS credentials
4. Installs AWS SAM CLI
5. Validates required secrets
6. Builds and deploys backend with SAM
7. Creates/updates:
   - Lambda
   - API Gateway
   - S3 bucket
   - DynamoDB table
   - IAM permissions
   - CloudWatch Log Group
8. Reads the API Gateway URL from CloudFormation outputs
9. Builds React with VITE_API_BASE_URL set to that API URL
10. SSHs into EC2
11. Installs/configures Nginx if needed
12. Pushes full source code to /opt/cloudmentor
13. Publishes frontend/dist to /var/www/cloudmentor
14. Reloads Nginx
```

---

## 10. Deploy from GitHub Actions

Push the project to GitHub:

```bash
git init
git add .
git commit -m "Initial CloudMentor prod deployment"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

Then go to:

```text
GitHub repository -> Actions -> Deploy CloudMentor Production
```

Watch the workflow logs.

After success, open:

```text
http://YOUR_EC2_PUBLIC_IP
```

---

## 11. Backend resources created by SAM

`backend/template.yaml` creates:

### Lambda

```text
CloudMentorFunction
Runtime: nodejs22.x
Handler: src/app.handler
```

### API Gateway

Endpoints:

```text
GET  /health
POST /summarize
POST /quiz
POST /flashcards
POST /study-plan
POST /upload-url
POST /process-file
GET  /history
POST /save-progress
```

### S3

Private bucket for uploaded study materials.

S3 is used when students upload files from the frontend. The backend generates a pre-signed URL, the browser uploads the file to S3, and Lambda processes supported text files.

### DynamoDB

Stores AI response history and progress records.

### CloudWatch

The template creates a Lambda log group with 14-day retention:

```text
/aws/lambda/<stack-name>-api
```

---

## 12. Verify production deployment

### Frontend

```bash
curl http://YOUR_EC2_PUBLIC_IP/healthz
```

Expected:

```text
cloudmentor-ec2-ok
```

### Backend

Use the API Gateway URL from the GitHub Actions summary or AWS CloudFormation output:

```bash
curl https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/health
```

Expected response includes:

```json
{
  "ok": true,
  "service": "CloudMentor API",
  "storageMode": "s3",
  "aiMode": "openai"
}
```

If you deployed with mock mode, `aiMode` will show:

```json
"aiMode": "mock"
```

---

## 13. Common issues

### Frontend still calls localhost

You built the frontend locally or `.env` was used manually.

In production, GitHub Actions sets:

```text
VITE_API_BASE_URL=<real API Gateway URL>
```

Re-run the workflow.

### CORS error

Set GitHub secret:

```text
CORS_ORIGIN=http://YOUR_EC2_PUBLIC_IP
```

Then re-run the workflow.

For quick classroom demo only, you can set:

```text
CORS_ORIGIN=*
```

### OpenAI key error

If using real AI:

```text
AI_MODE=openai
OPENAI_API_KEY=sk-proj-your-real-key
```

If using mock mode:

```text
AI_MODE=mock
```

### EC2 SSH failure

Check:

```text
EC2_HOST is correct
EC2_USER is ubuntu
EC2_SSH_KEY contains the full private key
Security group allows SSH from GitHub Actions runner IPs or temporarily from 0.0.0.0/0 for class demo
```

For better security, restrict SSH after deployment.

### SAM deploy permission error

The AWS credentials used by GitHub Actions need permission to create/update CloudFormation, Lambda, API Gateway, S3, DynamoDB, IAM roles, and CloudWatch Logs.

---

## 14. Cleanup

Delete backend stack:

```bash
aws cloudformation delete-stack \
  --stack-name cloudmentor-prod \
  --region ap-southeast-1
```

Terminate EC2 manually from the AWS Console when done.

If the S3 bucket has uploaded files, CloudFormation may not delete it until the bucket is empty.

---

## 15. Teaching explanation

Use this explanation with students:

```text
Frontend and backend are deployed differently.

React is compiled into static HTML, CSS, and JavaScript. We serve that from EC2 using Nginx.

The backend is not running on EC2. The backend is real serverless AWS infrastructure. GitHub Actions uses AWS SAM to create Lambda, API Gateway, S3, DynamoDB, IAM, and CloudWatch resources.

The frontend does not know the OpenAI key. It only knows the API Gateway URL. Lambda owns the secret and calls OpenAI securely from the backend.
```
