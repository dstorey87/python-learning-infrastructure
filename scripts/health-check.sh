#!/bin/bash

# Health Check Script for Python Learning Portal Services
# Usage: ./health-check.sh <environment> [service]

set -e

ENVIRONMENT=${1:-dev}
SERVICE=${2:-all}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get base URL for environment
get_base_url() {
    case $ENVIRONMENT in
        "dev")
            echo "https://dev-api.python-learning-portal.com"
            ;;
        "staging")
            echo "https://staging-api.python-learning-portal.com"
            ;;
        "prod")
            echo "https://api.python-learning-portal.com"
            ;;
        "local")
            echo "http://localhost"
            ;;
        *)
            print_error "Unknown environment: $ENVIRONMENT"
            exit 1
            ;;
    esac
}

# Health check for a single service
check_service_health() {
    local service_name=$1
    local service_url=$2
    local timeout=${3:-10}
    
    print_status "Checking health of $service_name at $service_url"
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "$service_url/health" || echo "000")
    
    if [ "$response" = "200" ]; then
        print_success "$service_name is healthy (HTTP $response)"
        return 0
    else
        print_error "$service_name is unhealthy (HTTP $response)"
        return 1
    fi
}

# Check detailed service status
check_service_status() {
    local service_name=$1
    local service_url=$2
    
    print_status "Getting detailed status for $service_name"
    
    local response=$(curl -s --connect-timeout 10 "$service_url/health" 2>/dev/null || echo '{"status":"error","message":"Unable to connect"}')
    
    echo "Response: $response" | jq '.' 2>/dev/null || echo "Raw response: $response"
    echo ""
}

# Check database connectivity
check_database() {
    local base_url=$1
    
    print_status "Checking database connectivity"
    
    local response=$(curl -s --connect-timeout 10 "$base_url:8080/health/db" 2>/dev/null || echo '{"status":"error"}')
    local status=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "unknown")
    
    if [ "$status" = "ok" ]; then
        print_success "Database is connected and healthy"
    else
        print_error "Database connection failed"
        echo "Response: $response"
    fi
}

# Check Redis connectivity
check_redis() {
    local base_url=$1
    
    print_status "Checking Redis connectivity"
    
    local response=$(curl -s --connect-timeout 10 "$base_url:8080/health/redis" 2>/dev/null || echo '{"status":"error"}')
    local status=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "unknown")
    
    if [ "$status" = "ok" ]; then
        print_success "Redis is connected and healthy"
    else
        print_error "Redis connection failed"
        echo "Response: $response"
    fi
}

# Check ECS service status
check_ecs_service() {
    local service_name=$1
    local cluster_name="python-learning-portal-${ENVIRONMENT}"
    
    if [ "$ENVIRONMENT" = "local" ]; then
        print_warning "Skipping ECS check for local environment"
        return 0
    fi
    
    print_status "Checking ECS service: $service_name"
    
    local service_info=$(aws ecs describe-services \
        --cluster "$cluster_name" \
        --services "$service_name" \
        --query 'services[0]' 2>/dev/null || echo '{}')
    
    local running_count=$(echo "$service_info" | jq -r '.runningCount // 0')
    local desired_count=$(echo "$service_info" | jq -r '.desiredCount // 0')
    local status=$(echo "$service_info" | jq -r '.status // "UNKNOWN"')
    
    if [ "$status" = "ACTIVE" ] && [ "$running_count" -eq "$desired_count" ]; then
        print_success "ECS service $service_name is healthy ($running_count/$desired_count tasks running)"
    else
        print_error "ECS service $service_name is not healthy"
        echo "Status: $status, Running: $running_count, Desired: $desired_count"
    fi
}

# Check load balancer health
check_load_balancer() {
    if [ "$ENVIRONMENT" = "local" ]; then
        print_warning "Skipping load balancer check for local environment"
        return 0
    fi
    
    local lb_name="python-learning-portal-${ENVIRONMENT}"
    
    print_status "Checking Application Load Balancer: $lb_name"
    
    local lb_info=$(aws elbv2 describe-load-balancers \
        --names "$lb_name" \
        --query 'LoadBalancers[0]' 2>/dev/null || echo '{}')
    
    local state=$(echo "$lb_info" | jq -r '.State.Code // "unknown"')
    
    if [ "$state" = "active" ]; then
        print_success "Load balancer $lb_name is active"
    else
        print_error "Load balancer $lb_name is not active (state: $state)"
    fi
}

# Comprehensive health check
comprehensive_check() {
    local base_url=$(get_base_url)
    local services=("frontend:3000" "api:8080" "auth:8081" "executor:5000")
    local failed_services=()
    
    print_status "Starting comprehensive health check for $ENVIRONMENT environment"
    print_status "Base URL: $base_url"
    echo ""
    
    # Check individual services
    for service_info in "${services[@]}"; do
        IFS=':' read -ra ADDR <<< "$service_info"
        local service_name="${ADDR[0]}"
        local port="${ADDR[1]}"
        local service_url="$base_url:$port"
        
        if [ "$ENVIRONMENT" = "local" ]; then
            service_url="http://localhost:$port"
        fi
        
        if ! check_service_health "$service_name" "$service_url"; then
            failed_services+=("$service_name")
        fi
        
        # Get detailed status for failed services
        if [ ${#failed_services[@]} -gt 0 ] && [[ " ${failed_services[*]} " =~ " $service_name " ]]; then
            check_service_status "$service_name" "$service_url"
        fi
        
        # Check ECS service status
        check_ecs_service "$service_name"
        
        echo ""
    done
    
    # Check infrastructure components
    check_database "$base_url"
    check_redis "$base_url"
    check_load_balancer
    
    echo ""
    print_status "Health check summary:"
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        print_success "All services are healthy! ✅"
        exit 0
    else
        print_error "Failed services: ${failed_services[*]} ❌"
        exit 1
    fi
}

# Single service check
single_service_check() {
    local base_url=$(get_base_url)
    local port
    
    case $SERVICE in
        "frontend")
            port="3000"
            ;;
        "api")
            port="8080"
            ;;
        "auth")
            port="8081"
            ;;
        "executor")
            port="5000"
            ;;
        *)
            print_error "Unknown service: $SERVICE"
            print_status "Available services: frontend, api, auth, executor"
            exit 1
            ;;
    esac
    
    local service_url="$base_url:$port"
    if [ "$ENVIRONMENT" = "local" ]; then
        service_url="http://localhost:$port"
    fi
    
    check_service_health "$SERVICE" "$service_url"
    check_service_status "$SERVICE" "$service_url"
    check_ecs_service "$SERVICE"
}

# Show usage information
show_usage() {
    echo "Usage: $0 <environment> [service]"
    echo ""
    echo "Environments: dev, staging, prod, local"
    echo "Services: frontend, api, auth, executor, all"
    echo ""
    echo "Examples:"
    echo "  $0 dev                    # Check all services in dev"
    echo "  $0 prod api              # Check only API service in prod"
    echo "  $0 local                 # Check all services locally"
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    # Check if required tools are available
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. JSON responses will not be formatted"
    fi
    
    if [ "$ENVIRONMENT" != "local" ] && ! command -v aws &> /dev/null; then
        print_warning "AWS CLI is not installed. ECS and ALB checks will be skipped"
    fi
    
    if [ "$SERVICE" = "all" ]; then
        comprehensive_check
    else
        single_service_check
    fi
}

# Run main function
main "$@"