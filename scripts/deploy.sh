#!/bin/bash

# ECS Deployment Script for Python Learning Portal
# Usage: ./deploy.sh <environment> <build_number>

set -e  # Exit on any error

ENVIRONMENT=${1:-dev}
BUILD_NUMBER=${2:-latest}
PROJECT_NAME="python-learning-portal"
AWS_REGION=${AWS_DEFAULT_REGION:-us-east-1}

echo "🚀 Starting deployment to $ENVIRONMENT environment"
echo "Build Number: $BUILD_NUMBER"
echo "AWS Region: $AWS_REGION"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check required environment variables
check_env() {
    local required_vars=(
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
        "SUPABASE_URL"
        "STRIPE_SECRET_KEY"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    print_status "Environment variables validated"
}

# Update ECS service with new image
update_ecs_service() {
    local service_name=$1
    local cluster_name="${PROJECT_NAME}-${ENVIRONMENT}"
    local image_uri="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-${service_name}:${BUILD_NUMBER}"
    
    print_status "Updating ECS service: $service_name"
    
    # Get current task definition
    local task_def_arn=$(aws ecs describe-services \
        --cluster "$cluster_name" \
        --services "$service_name" \
        --query 'services[0].taskDefinition' \
        --output text)
    
    # Get current task definition details
    local task_def=$(aws ecs describe-task-definition \
        --task-definition "$task_def_arn" \
        --query 'taskDefinition')
    
    # Update image URI in task definition
    local new_task_def=$(echo "$task_def" | jq --arg image "$image_uri" '
        .containerDefinitions[0].image = $image |
        del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .placementConstraints, .compatibilities, .registeredAt, .registeredBy)
    ')
    
    # Register new task definition
    local new_task_def_arn=$(echo "$new_task_def" | aws ecs register-task-definition \
        --cli-input-json file:///dev/stdin \
        --query 'taskDefinition.taskDefinitionArn' \
        --output text)
    
    print_status "New task definition registered: $new_task_def_arn"
    
    # Update service with new task definition
    aws ecs update-service \
        --cluster "$cluster_name" \
        --service "$service_name" \
        --task-definition "$new_task_def_arn" > /dev/null
    
    print_status "Service $service_name updated successfully"
}

# Wait for service to be stable
wait_for_deployment() {
    local service_name=$1
    local cluster_name="${PROJECT_NAME}-${ENVIRONMENT}"
    
    print_status "Waiting for $service_name deployment to complete..."
    
    aws ecs wait services-stable \
        --cluster "$cluster_name" \
        --services "$service_name"
    
    if [ $? -eq 0 ]; then
        print_status "$service_name deployment completed successfully"
    else
        print_error "$service_name deployment failed or timed out"
        return 1
    fi
}

# Update secrets in AWS Secrets Manager
update_secrets() {
    print_status "Updating secrets in AWS Secrets Manager"
    
    local secrets=(
        "database-password:$DATABASE_PASSWORD"
        "supabase-url:$SUPABASE_URL"
        "supabase-service-key:$SUPABASE_SERVICE_KEY"
        "stripe-secret-key:$STRIPE_SECRET_KEY"
        "jwt-secret:$JWT_SECRET"
    )
    
    for secret in "${secrets[@]}"; do
        IFS=':' read -ra ADDR <<< "$secret"
        local secret_name="${PROJECT_NAME}-${ENVIRONMENT}-${ADDR[0]}"
        local secret_value="${ADDR[1]}"
        
        if [ ! -z "$secret_value" ]; then
            aws secretsmanager put-secret-value \
                --secret-id "$secret_name" \
                --secret-string "$secret_value" > /dev/null
            print_status "Updated secret: $secret_name"
        fi
    done
}

# Run database migrations
run_migrations() {
    print_status "Running database migrations"
    
    local cluster_name="${PROJECT_NAME}-${ENVIRONMENT}"
    local task_def_name="${PROJECT_NAME}-api-${ENVIRONMENT}"
    
    # Run migration task
    local task_arn=$(aws ecs run-task \
        --cluster "$cluster_name" \
        --task-definition "$task_def_name" \
        --overrides '{
            "containerOverrides": [{
                "name": "api",
                "command": ["npm", "run", "migrate"]
            }]
        }' \
        --query 'tasks[0].taskArn' \
        --output text)
    
    print_status "Migration task started: $task_arn"
    
    # Wait for migration to complete
    aws ecs wait tasks-stopped \
        --cluster "$cluster_name" \
        --tasks "$task_arn"
    
    # Check migration exit code
    local exit_code=$(aws ecs describe-tasks \
        --cluster "$cluster_name" \
        --tasks "$task_arn" \
        --query 'tasks[0].containers[0].exitCode' \
        --output text)
    
    if [ "$exit_code" = "0" ]; then
        print_status "Database migrations completed successfully"
    else
        print_error "Database migrations failed with exit code: $exit_code"
        return 1
    fi
}

# Health check function
health_check() {
    local service_url=$1
    local max_attempts=30
    local attempt=1
    
    print_status "Performing health check on $service_url"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$service_url/health" > /dev/null; then
            print_status "Health check passed on attempt $attempt"
            return 0
        fi
        
        print_warning "Health check failed on attempt $attempt/$max_attempts"
        sleep 10
        ((attempt++))
    done
    
    print_error "Health check failed after $max_attempts attempts"
    return 1
}

# Rollback function
rollback() {
    print_error "Deployment failed. Initiating rollback..."
    
    local services=("frontend" "api" "auth" "executor")
    local cluster_name="${PROJECT_NAME}-${ENVIRONMENT}"
    
    for service in "${services[@]}"; do
        print_warning "Rolling back service: $service"
        
        # Get previous task definition
        local previous_task_def=$(aws ecs describe-services \
            --cluster "$cluster_name" \
            --services "$service" \
            --query 'services[0].deployments[1].taskDefinition' \
            --output text)
        
        if [ "$previous_task_def" != "None" ]; then
            aws ecs update-service \
                --cluster "$cluster_name" \
                --service "$service" \
                --task-definition "$previous_task_def" > /dev/null
            
            print_warning "Service $service rolled back to $previous_task_def"
        fi
    done
}

# Main deployment process
main() {
    print_status "Starting deployment process"
    
    # Validate environment
    check_env
    
    # Update secrets
    update_secrets
    
    # Services to deploy
    local services=("frontend" "api" "auth" "executor")
    
    # Deploy services
    for service in "${services[@]}"; do
        if ! update_ecs_service "$service"; then
            rollback
            exit 1
        fi
    done
    
    # Run database migrations (only for API service)
    if ! run_migrations; then
        rollback
        exit 1
    fi
    
    # Wait for all deployments to stabilize
    for service in "${services[@]}"; do
        if ! wait_for_deployment "$service"; then
            rollback
            exit 1
        fi
    done
    
    # Health checks
    local base_url=""
    case $ENVIRONMENT in
        "dev")
            base_url="https://dev-api.python-learning-portal.com"
            ;;
        "staging")
            base_url="https://staging-api.python-learning-portal.com"
            ;;
        "prod")
            base_url="https://api.python-learning-portal.com"
            ;;
    esac
    
    if ! health_check "$base_url"; then
        rollback
        exit 1
    fi
    
    print_status "🎉 Deployment to $ENVIRONMENT completed successfully!"
    print_status "Application URL: ${base_url/api./}"
}

# Trap errors and run rollback
trap rollback ERR

# Run main function
main "$@"