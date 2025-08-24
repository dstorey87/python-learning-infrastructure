# Python Learning Portal - Infrastructure

This repository contains all infrastructure code, deployment scripts, and configuration for the Python Learning Portal microservices architecture on AWS ECS.

## 🏗️ Architecture Overview

The Python Learning Portal is deployed as a microservices architecture using:

- **AWS ECS Fargate** - Container orchestration
- **Application Load Balancer** - Traffic distribution
- **Amazon RDS PostgreSQL** - Primary database
- **Amazon ElastiCache Redis** - Caching and sessions
- **AWS Secrets Manager** - Secure credential storage
- **Amazon ECR** - Docker image registry
- **HashiCorp Vault** - External secrets management
- **Terraform** - Infrastructure as Code
- **Jenkins** - CI/CD pipeline automation

## 📁 Repository Structure

```
├── terraform/
│   ├── modules/           # Reusable Terraform modules
│   │   ├── ecs/          # ECS cluster and services
│   │   ├── networking/   # VPC, subnets, security groups
│   │   ├── database/     # RDS PostgreSQL
│   │   ├── cache/        # ElastiCache Redis
│   │   └── monitoring/   # CloudWatch, logging
│   └── environments/     # Environment-specific configurations
│       ├── dev/
│       ├── staging/
│       └── prod/
├── docker/
│   ├── docker-compose.local.yml    # Local development
│   └── docker-compose.prod.yml     # Production reference
├── jenkins/
│   └── Jenkinsfile       # CI/CD pipeline configuration
├── scripts/
│   ├── deploy.sh         # ECS deployment script
│   ├── setup-local-dev.sh # Local development setup
│   └── health-check.sh   # Service health verification
└── docs/
    ├── DEPLOYMENT.md     # Deployment procedures
    ├── MONITORING.md     # Observability setup
    └── TROUBLESHOOTING.md # Common issues and solutions
```

## 🚀 Quick Start

### Prerequisites

- **AWS CLI** configured with appropriate permissions
- **Terraform** >= 1.5.0
- **Docker** and Docker Compose
- **Node.js** >= 18.x
- **Python** >= 3.9
- **Git**

### Local Development Setup

1. Clone this repository:
```bash
git clone https://github.com/dstorey87/python-learning-infrastructure.git
cd python-learning-infrastructure
```

2. Run the local development setup script:
```bash
chmod +x scripts/setup-local-dev.sh
./scripts/setup-local-dev.sh
```

3. Start local services:
```bash
cd workspace
npm run docker:up  # Start PostgreSQL and Redis
npm run dev        # Start all microservices
```

4. Access the application:
- **Frontend**: http://localhost:3000
- **API Service**: http://localhost:8080
- **Auth Service**: http://localhost:8081
- **Executor Service**: http://localhost:5000

## 🏗️ Infrastructure Deployment

### Initial Setup

1. **Configure AWS credentials:**
```bash
aws configure
```

2. **Initialize Terraform:**
```bash
cd terraform/environments/dev
terraform init
```

3. **Create infrastructure:**
```bash
terraform plan
terraform apply
```

### Environment Management

The infrastructure supports three environments:

- **Development** (`dev`) - Single instance, minimal resources
- **Staging** (`staging`) - Production-like, reduced capacity
- **Production** (`prod`) - High availability, auto-scaling

### Deployment Process

The deployment process is automated through Jenkins CI/CD pipeline:

1. **Code pushed to GitHub** triggers webhook
2. **Jenkins pipeline** runs tests and builds Docker images
3. **Images pushed to ECR** registry
4. **ECS services updated** with rolling deployment
5. **Health checks** verify successful deployment
6. **Rollback** automatically triggered on failure

## 🔧 Configuration

### Environment Variables

Key configuration is managed through AWS Secrets Manager and HashiCorp Vault:

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# Supabase Authentication
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-key

# Payment Processing
STRIPE_SECRET_KEY=sk_live_your-stripe-key

# Code Execution
PYTHON_EXECUTOR_URL=https://executor.your-domain.com
MAX_EXECUTION_TIME=30
```

### Terraform Variables

Configure each environment in `terraform/environments/{env}/terraform.tfvars`:

```hcl
# Core Configuration
project_name = "python-learning-portal"
environment  = "prod"
aws_region   = "us-east-1"

# Networking
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# ECS Configuration
ecs_cpu    = 512
ecs_memory = 1024
desired_count = 2

# Database Configuration
db_instance_class = "db.t3.micro"
db_allocated_storage = 20

# Domain Configuration
domain_name = "python-learning-portal.com"
```

## 📊 Monitoring and Logging

### CloudWatch Integration

- **Application logs** centralized in CloudWatch Logs
- **Custom metrics** for business KPIs
- **Alerts** for critical failures and performance issues
- **Dashboards** for operational visibility

### Health Checks

Each service exposes `/health` endpoint for:
- **ECS health checks** for container management
- **ALB health checks** for load balancing
- **External monitoring** integration

## 🔒 Security

### Network Security

- **Private subnets** for database and internal services
- **NAT Gateway** for outbound internet access
- **Security groups** with least-privilege access
- **WAF** protection for public endpoints

### Secrets Management

- **AWS Secrets Manager** for AWS-native credential storage
- **HashiCorp Vault** for external secrets management
- **IAM roles** with minimal required permissions
- **Encrypted storage** for all data at rest

### Container Security

- **Non-root users** in all containers
- **Minimal base images** (Alpine Linux)
- **Security scanning** in CI/CD pipeline
- **Read-only root filesystems** where possible

## 📈 Scaling and Performance

### Auto Scaling

- **ECS Service Auto Scaling** based on CPU/memory
- **Database Read Replicas** for high-traffic scenarios
- **CloudFront CDN** for static asset delivery
- **Redis clustering** for cache scaling

### Performance Optimization

- **Application Load Balancer** with sticky sessions
- **Database connection pooling**
- **Redis caching** for frequently accessed data
- **Gzip compression** for API responses

## 🛠️ Development Workflow

### Branch Strategy

- `main` - Production releases
- `develop` - Integration branch
- `feature/*` - Feature development
- `hotfix/*` - Emergency fixes

### CI/CD Pipeline

1. **Pull Request** - Automated testing
2. **Merge to develop** - Deploy to development environment
3. **Release branch** - Deploy to staging
4. **Merge to main** - Deploy to production

### Testing Strategy

- **Unit tests** - Individual service testing
- **Integration tests** - Service interaction testing
- **E2E tests** - Full application flow testing
- **Load testing** - Performance validation

## 📚 Documentation

- [Deployment Guide](docs/DEPLOYMENT.md) - Detailed deployment procedures
- [Monitoring Setup](docs/MONITORING.md) - Observability configuration
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [API Documentation](https://api.python-learning-portal.com/docs) - Service APIs

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/dstorey87/python-learning-infrastructure/issues)
- **Documentation**: [Wiki](https://github.com/dstorey87/python-learning-infrastructure/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/dstorey87/python-learning-infrastructure/discussions)

---

## 🏷️ Related Repositories

- [Frontend Service](https://github.com/dstorey87/python-learning-frontend) - React TypeScript frontend
- [API Service](https://github.com/dstorey87/python-learning-api) - Node.js REST API
- [Auth Service](https://github.com/dstorey87/python-learning-auth) - Authentication microservice
- [Executor Service](https://github.com/dstorey87/python-learning-executor) - Python code execution
- [Shared Types](https://github.com/dstorey87/python-learning-shared) - TypeScript type definitions

## 📊 AWS Cost Optimization

This infrastructure is designed to work within AWS Free Tier limits:

- **ECS Fargate**: 20 GB-hours per month of vCPU and 40 GB-hours of memory
- **RDS**: 750 hours of db.t2.micro instance usage
- **ElastiCache**: 750 hours of cache.t2.micro node usage
- **ALB**: 750 hours and 15 GB of data processing
- **Data Transfer**: 15 GB of data transfer out

Estimated monthly cost for development environment: **$5-15/month** beyond free tier.

## 🔄 Maintenance

- **Weekly**: Review CloudWatch alarms and performance metrics
- **Monthly**: Update Docker base images for security patches
- **Quarterly**: Review and rotate access keys and certificates
- **As needed**: Scale resources based on usage patterns