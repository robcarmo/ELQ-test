# Eloquent AI - ECS Deployment

Simple FastAPI application deployed on AWS ECS with Fargate, managed via Terraform and GitHub Actions.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Deployment Instructions](#deployment-instructions)
- [CI/CD Flow](#cicd-flow)
- [Security Considerations](#security-considerations)
- [Design Decisions](#design-decisions)
- [Monitoring](#monitoring)
- [Cost Estimate](#cost-estimate)
- [Project Structure](#project-structure)

---

## Architecture Overview

### High-Level Design

```
Internet → ALB (Public Subnets) → ECS Fargate Tasks (Private Subnets) → NAT Gateway → Internet Gateway
```

### Components

- **VPC**: Multi-AZ deployment across 2 availability zones
- **Public Subnets**: Host Application Load Balancer and NAT Gateways
- **Private Subnets**: Host ECS Fargate tasks (no direct internet access)
- **ALB**: Distributes traffic and performs health checks
- **ECS Fargate**: Runs containerized application (2-4 tasks with auto-scaling)
- **ECR**: Stores Docker images with encryption and lifecycle policies
- **CloudWatch**: Centralized logging, metrics, and alarms
- **IAM**: Least-privilege roles for task execution and runtime

### Key Features

- **High Availability**: Multi-AZ deployment with automatic failover
- **Security**: Private subnets, security groups, encrypted data
- **Scalability**: Auto-scaling based on CPU/memory (1-4 tasks)
- **Monitoring**: CloudWatch logs, metrics, and alarms
- **CI/CD**: Automated deployment with rollback capabilities

---

## Prerequisites

Before deploying, ensure you have:

- **AWS Account** with administrative access
- **AWS CLI** installed and configured (`aws configure`)
- **Terraform** >= 1.6.0 installed
- **Docker** installed (for local testing)
- **GitHub Account** for CI/CD pipelines
- **Git** installed

---

## Deployment Instructions

### Option 1: Automated Deployment (Recommended)

#### Step 1: Choose a State Management Approach

You have two options for Terraform state management:

**A. Remote State (Production Ready):**
Create S3 bucket for Terraform state:
```bash
aws s3 mb s3://eloquent-ai-terraform-state-$(date +%s) --region us-east-1
```
Save the bucket name for the next step.

**B. Local State (Testing/Development):**
For testing or development, you can use local state management by commenting out the S3 backend configuration in `terraform/versions.tf`:

```hcl
# Comment out for local state management during testing
# backend "s3" {
#   bucket = "your-bucket-name-here"
#   key    = "eloquent-ai/terraform.tfstate"
#   region = "us-east-1"
#   encrypt = true
# }
```

#### Step 2: Configure GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `wJalrXUtnFEMI/K7MDENG/...` |
| `TF_STATE_BUCKET` | S3 bucket from Step 1 (optional for testing) | `eloquent-ai-terraform-state-1234567890` |

#### Step 3: Update Terraform Backend (For Remote State)

If using remote state, edit `terraform/versions.tf` and update the S3 bucket name:

```hcl
backend "s3" {
  bucket = "your-bucket-name-here"  # Update this
  key    = "eloquent-ai/terraform.tfstate"
  region = "us-east-1"
  encrypt = true
}
```

If using local state for testing, you can skip this step.

#### Step 4: Deploy

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

GitHub Actions will automatically:
1. Deploy infrastructure (Terraform workflow)
2. Build and push Docker image (Deploy workflow)
3. Deploy application to ECS

Monitor progress in the **Actions** tab of your GitHub repository.

### Option 2: Manual Deployment

#### Step 1: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init \
  -backend-config="bucket=YOUR_BUCKET_NAME" \
  -backend-config="key=eloquent-ai/terraform.tfstate" \
  -backend-config="region=us-east-1"

# Review changes
terraform plan

# Deploy infrastructure
terraform apply
```

#### Step 2: Build and Push Docker Image

```bash
# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1
ECR_REPO=eloquent-ai-app

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build image
docker build -t $ECR_REPO:latest .

# Tag image
docker tag $ECR_REPO:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest

# Push to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:latest
```

#### Step 3: Deploy to ECS

```bash
aws ecs update-service \
  --cluster eloquent-ai-cluster \
  --service eloquent-ai-service \
  --force-new-deployment \
  --region us-east-1
```

### Verification

#### Get ALB URL

```bash
cd terraform
terraform output alb_dns_name
```

#### Test Endpoints

```bash
ALB_URL="http://your-alb-dns-name"

# Health check
curl $ALB_URL/health
# Expected: {"status":"healthy","version":"1.0.0"}

# API endpoint
curl $ALB_URL/api/hello
# Expected: {"message":"Hello from Eloquent AI!","environment":"dev"}
```

---

## CI/CD Flow

### Workflows

The deployment pipeline consists of three GitHub Actions workflows:

#### 1. Terraform Workflow (`terraform.yml`)

**Triggers**:
- `pull_request` on `main` when `terraform/**` changes → runs fmt/validate/plan only
- `workflow_dispatch` (manual) with input `action = apply | destroy` → runs `terraform apply` or `terraform destroy`

**Steps**:
1. **Checkout**: Clone repository
2. **Setup Terraform**: Install Terraform 1.6.0
3. **Configure AWS**: Set up AWS credentials
4. **Init**: Initialize Terraform backend (S3 or local state)
5. **Format**: Check code formatting (`terraform fmt`)
6. **Validate**: Validate Terraform syntax
7. **Plan**: Generate execution plan (on PR)
8. **Apply/Destroy**: Apply or destroy infrastructure **only when manually triggered** via `workflow_dispatch`

#### 2. Build, Test, Push, and Deploy Workflow (`build-and-push.yml`)

**Triggers**:
- `pull_request` on `main` when `app/**` changes → runs linting and unit tests only
- `push` to `main` when `app/**` changes → runs linting, unit tests, builds image, pushes to ECR, and deploys to ECS
- `workflow_dispatch` (manual) → same behavior as push to `main` (end-to-end pipeline)

**Steps**:
1. **Checkout**: Clone repository
2. **Setup Python**: Install Python 3.11
3. **Install tooling**: Install `flake8` and `pytest`
4. **Install app dependencies**: Install from `app/requirements.txt`
5. **Lint**: Run flake8 on `app/app.py`
6. **Unit tests**: Run pytest against `app/test_app.py`
7. **Configure AWS**: Set up AWS credentials (non-PR runs)
8. **Login to ECR**: Authenticate with container registry (non-PR runs)
9. **Build**: Create Docker image using `app/Dockerfile` with Docker buildx (non-PR runs)
10. **Push**: Upload image to ECR with git SHA tag and `latest` tag (non-PR runs)
11. **Update Task Definition**: Render ECS task definition with new image (non-PR runs)
12. **Deploy**: Deploy to ECS with rolling update (non-PR runs)
13. **Rollback**: Automatically rollback on failure (non-PR runs)

#### 3. Deploy Workflow (`deploy.yml`)

**Trigger**:
- `workflow_dispatch` (manual) with input `image_uri` (e.g. `149399235178.dkr.ecr.us-east-1.amazonaws.com/eloquent-ai-app:TAG`)

**Steps**:
1. **Checkout**: Clone repository
2. **Configure AWS**: Set up AWS credentials
3. **Get Task Definition**: Fetch current ECS task definition
4. **Update Task Definition**: Replace container image with the provided `image_uri`
5. **Deploy**: Deploy updated task definition to ECS with rolling update
6. **Rollback**: Automatically rollback on failure

### Deployment Strategy

- **Rolling Updates**: New tasks are started before old tasks are stopped
- **Health Checks**: ALB ensures new tasks are healthy before routing traffic
- **Circuit Breaker**: Automatically rolls back on failure
- **Circuit Breaker**: Automatically rolls back if deployment fails
- **Zero Downtime**: Traffic continues to flow during deployments

### Rollback Capabilities

- **Automatic**: Deployment workflow rolls back on failure
- **Manual**: Use AWS CLI to revert to previous task definition:
  ```bash
  aws ecs update-service \
    --cluster eloquent-ai-cluster \
    --service eloquent-ai-service \
    --task-definition eloquent-ai-task:PREVIOUS_REVISION
  ```

---

## Security Considerations

### Implemented Security Measures

#### Network Security
- **Private Subnets**: ECS tasks have no direct internet access
- **Security Groups**: Restrict traffic (ALB → ECS on port 8080 only)
- **NAT Gateways**: Controlled outbound access for updates
- **Network Isolation**: Multi-layer defense with public/private subnet separation

#### IAM Security
- **Task Execution Role**: Minimal permissions for ECR pull and CloudWatch logs
- **Task Role**: Application-level permissions (currently minimal)
- **Least Privilege**: All roles follow principle of least privilege
- **No Hardcoded Credentials**: Uses GitHub Secrets and IAM roles

#### Data Security
- **Encryption at Rest**:
  - ECR images: AES-256 encryption
  - S3 Terraform state: AES-256 encryption with versioning
  - CloudWatch logs: Encrypted
- **Encryption in Transit**:
  - ALB to ECS: HTTP (can be upgraded to HTTPS)
  - ECS to AWS APIs: HTTPS

#### Container Security
- **Multi-stage Builds**: Minimized image size and attack surface
- **Non-root User**: Container runs as non-privileged user
- **ECR Scanning**: Image vulnerability scanning enabled
- **Immutable Tags**: Git SHA-based tagging prevents tag mutation

### Production Enhancements

For production deployment, add:

1. **HTTPS/TLS**:
   - Route53 for custom domain
   - ACM certificate
   - HTTPS listener on ALB
   - HTTP to HTTPS redirect

2. **Enhanced Monitoring**:
   - CloudWatch dashboards
   - SNS notifications for alarms
   - AWS X-Ray for distributed tracing
   - Container Insights

3. **Additional Security**:
   - AWS WAF on ALB
   - AWS Secrets Manager for sensitive data
   - VPC Flow Logs
   - GuardDuty for threat detection
   - Security Hub for compliance

4. **Compliance**:
   - AWS Config for compliance monitoring
   - CloudTrail for audit logging
   - Regular security assessments

---

## Design Decisions

### Architecture Choices

#### 1. ECS Fargate vs EC2

**Choice**: Fargate

**Rationale**:
- No server management overhead
- Automatic scaling and patching
- Pay-per-task pricing model
- Simpler operations and maintenance

**Trade-off**: Slightly higher cost than EC2, but operational simplicity justifies it for this use case.

#### 2. Application Load Balancer vs Network Load Balancer

**Choice**: ALB

**Rationale**:
- HTTP/HTTPS routing capabilities
- Application-level health checks
- Better suited for web applications
- Native CloudWatch integration

#### 3. Multi-AZ Deployment

**Choice**: 2 Availability Zones

**Rationale**:
- High availability and fault tolerance
- Meets production standards
- Balances cost vs reliability
- Automatic failover

#### 4. Private Subnets for ECS

**Choice**: Private subnets with NAT Gateway

**Rationale**:
- Security best practice
- No direct internet exposure
- Controlled outbound access
- Industry standard architecture

#### 5. Terraform Modules

**Choice**: Modular structure (VPC, ECR, ECS, ALB)

**Rationale**:
- Reusability across projects
- Easier maintenance and testing
- Clear separation of concerns
- Follows Terraform best practices

#### 6. GitHub Actions for CI/CD

**Choice**: GitHub Actions over Jenkins/CircleCI

**Rationale**:
- Native GitHub integration
- No infrastructure to manage
- Free for public repositories
- Simple YAML configuration

### Trade-offs Considered

#### NAT Gateway Cost

**Issue**: NAT Gateways cost ~$65/month for 2 AZs (60% of total cost)

**Alternatives Considered**:
1. **Single NAT Gateway**: Saves ~$32/month but reduces availability
2. **VPC Endpoints**: Saves NAT costs but adds complexity
3. **Public Subnets**: Saves costs but significantly reduces security

**Decision**: Keep 2 NAT Gateways for production-grade availability. For cost-sensitive environments, consider single NAT or VPC endpoints.

#### Auto-scaling Configuration

**Current**: Min 1, Desired 2, Max 4 tasks

**Rationale**:
- Minimum 1 for cost savings during low traffic
- Desired 2 for high availability
- Max 4 to prevent runaway costs
- Easily adjustable based on actual load patterns

#### Container Resources

**Current**: 256 CPU, 512 MB memory

**Rationale**:
- Smallest Fargate configuration
- Sufficient for simple API workload
- Cost-effective starting point
- Easy to scale up if needed

### What I'd Do Differently with More Time

#### 1. HTTPS/SSL
- Route53 for custom domain
- ACM certificate management
- HTTPS listener on ALB
- HTTP to HTTPS redirect

#### 2. Enhanced Monitoring
- Custom CloudWatch dashboards
- SNS notifications for alarms
- X-Ray for distributed tracing
- Container Insights for detailed metrics

#### 3. Security Enhancements
- AWS WAF for ALB protection
- Secrets Manager for sensitive data
- VPC Flow Logs for network monitoring
- GuardDuty integration
- Enhanced ECR image scanning

#### 4. Database Layer
- RDS or DynamoDB integration
- Database migrations
- Connection pooling
- Backup and recovery strategy

#### 5. CI/CD Improvements
- Blue/green deployments
- Canary releases
- Automated integration tests
- Performance testing
- Smoke tests post-deployment

#### 6. Cost Optimization
- Single NAT Gateway for dev environment
- VPC Endpoints for AWS services
- Spot instances for non-critical tasks
- CloudWatch log retention policies
- Reserved capacity (when available)

#### 7. Multi-Environment
- Separate dev/staging/prod environments
- Environment-specific configurations
- Terraform workspaces
- Separate AWS accounts for isolation

#### 8. Documentation
- API documentation (Swagger/OpenAPI)
- Runbooks for common issues
- Architecture diagrams
- Disaster recovery plan
- Incident response procedures

---

## Monitoring

### CloudWatch Logs

View application logs:
```bash
aws logs tail /ecs/eloquent-ai-cluster --follow
```

### Service Status

Check ECS service health:
```bash
aws ecs describe-services \
  --cluster eloquent-ai-cluster \
  --services eloquent-ai-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
```

### CloudWatch Alarms

Configured alarms:
- **High Response Time**: Triggers when ALB response time > 1 second
- **Unhealthy Hosts**: Triggers when any target is unhealthy

### Metrics

Key metrics to monitor:
- ECS: CPU utilization, memory utilization, task count
- ALB: Request count, response time, target health
- Custom: Application-specific metrics (can be added)

---

## Cost Estimate

### Monthly Breakdown

| Component | Cost | Notes |
|-----------|------|-------|
| ECS Fargate (2 tasks) | ~$15 | 0.25 vCPU, 0.5 GB per task |
| NAT Gateway (2 AZs) | ~$65 | Largest cost component |
| Application Load Balancer | ~$20 | Includes LCU charges |
| CloudWatch Logs & ECR | ~$5 | Based on 5GB logs, 1GB images |
| **Total** | **~$105/month** | Running 24/7 |

### Cost Optimization Options

1. **Single NAT Gateway**: ~$50/month (reduces availability)
2. **VPC Endpoints**: ~$20/month (adds complexity, saves NAT costs)
3. **Smaller tasks**: Minimal savings (already using smallest size)
4. **Reserved capacity**: Not available for Fargate

---

## Local Testing

Test the application locally before deploying:

```bash
# Build Docker image
docker build -t eloquent-ai-app .

# Run container
docker run -p 8080:8080 \
  -e APP_VERSION=1.0.0 \
  -e ENVIRONMENT=local \
  eloquent-ai-app

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/api/hello
```

---

## Configuration

Key variables in `terraform/variables.tf`:

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | `eloquent-ai` | Project identifier |
| `environment` | `dev` | Environment name |
| `aws_region` | `us-east-1` | AWS region |
| `container_cpu` | `256` | Task CPU units |
| `container_memory` | `512` | Task memory (MB) |
| `desired_count` | `2` | Number of tasks |
| `min_capacity` | `1` | Min auto-scaling tasks |
| `max_capacity` | `4` | Max auto-scaling tasks |

To customize, create `terraform/terraform.tfvars`:

```hcl
project_name = "my-project"
environment  = "production"
desired_count = 4
max_capacity = 10
```

---

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

**Warning**: This will delete all infrastructure including:
- ECS cluster and tasks
- ALB and target groups
- VPC and networking components
- ECR repository and images
- CloudWatch logs

---

## Project Structure

```
.
├── app/                        # Application directory
│   ├── app.py                 # FastAPI application
│   ├── test_app.py            # Unit tests for the application
│   ├── Dockerfile             # Container definition
│   ├── requirements.txt       # Python dependencies
│   └── .dockerignore          # Docker ignore rules
├── README.md                   # This file
├── .gitignore                  # Git ignore rules
├── .github/workflows/
│   ├── terraform.yml          # Infrastructure CI/CD
│   └── deploy.yml             # Application CI/CD
└── terraform/
    ├── main.tf                # Root module
    ├── variables.tf           # Input variables
    ├── outputs.tf             # Output values
    ├── versions.tf            # Provider versions
    ├── terraform.tfvars.example  # Example configuration
    └── modules/
        ├── vpc/               # VPC, subnets, gateways
        ├── ecr/               # Container registry
        ├── ecs/               # ECS cluster and service
        └── alb/               # Load balancer
```

---

## Troubleshooting

### Issue: Terraform state bucket doesn't exist

**Solution**: Create the S3 bucket first (see Deployment Instructions Step 1)

### Issue: ECS tasks not starting

**Solution**: Check CloudWatch logs
```bash
aws logs tail /ecs/eloquent-ai-cluster --follow
```

### Issue: ALB health checks failing

**Solution**:
1. Verify security groups allow ALB → ECS traffic on port 8080
2. Check application is listening on port 8080
3. Verify `/health` endpoint returns 200 status

### Issue: GitHub Actions failing

**Solution**:
1. Verify all secrets are set correctly in GitHub
2. Check AWS credentials have required permissions
3. Review workflow logs for specific errors

---

## References

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [simple-eks repository](https://github.com/example/simple-eks) - Referenced for Terraform patterns

---

## License

This project is provided as-is for the Eloquent AI technical assessment.
