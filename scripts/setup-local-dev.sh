#!/bin/bash

# Local Development Setup Script for Python Learning Portal Microservices
# This script clones all microservice repositories and sets up local development environment

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GITHUB_USER="dstorey87"
REPOSITORIES=(
    "python-learning-frontend"
    "python-learning-api"
    "python-learning-auth"
    "python-learning-executor"
    "python-learning-shared"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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

# Check if required tools are installed
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local required_tools=("git" "docker" "docker-compose" "node" "npm" "python3")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and run this script again"
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Clone or update repositories
setup_repositories() {
    print_step "Setting up microservice repositories..."
    
    local workspace_dir="$PROJECT_ROOT/workspace"
    mkdir -p "$workspace_dir"
    cd "$workspace_dir"
    
    for repo in "${REPOSITORIES[@]}"; do
        if [ -d "$repo" ]; then
            print_warning "Repository $repo already exists, pulling latest changes..."
            cd "$repo"
            git pull origin main
            cd ..
        else
            print_step "Cloning $repo..."
            git clone "https://github.com/$GITHUB_USER/$repo.git"
        fi
        print_success "Repository $repo is ready"
    done
}

# Install dependencies for all services
install_dependencies() {
    print_step "Installing dependencies for all services..."
    
    local workspace_dir="$PROJECT_ROOT/workspace"
    
    # Install shared library dependencies
    cd "$workspace_dir/python-learning-shared"
    print_step "Installing shared library dependencies..."
    npm ci
    npm run build
    npm pack
    print_success "Shared library built successfully"
    
    # Install frontend dependencies
    cd "$workspace_dir/python-learning-frontend"
    print_step "Installing frontend dependencies..."
    npm ci
    print_success "Frontend dependencies installed"
    
    # Install API dependencies
    cd "$workspace_dir/python-learning-api"
    print_step "Installing API dependencies..."
    npm ci
    print_success "API dependencies installed"
    
    # Install auth service dependencies
    cd "$workspace_dir/python-learning-auth"
    print_step "Installing auth service dependencies..."
    npm ci
    print_success "Auth service dependencies installed"
    
    # Install executor dependencies (Python)
    cd "$workspace_dir/python-learning-executor"
    print_step "Installing executor dependencies..."
    python3 -m pip install -r requirements.txt
    print_success "Executor dependencies installed"
}

# Create local environment configuration
create_env_files() {
    print_step "Creating local environment configuration..."
    
    local workspace_dir="$PROJECT_ROOT/workspace"
    
    # Create .env file for local development
    cat > "$workspace_dir/.env.local" << EOF
# Local Development Environment Variables
NODE_ENV=development
PORT=3000

# Database Configuration
DATABASE_URL=postgresql://postgres:password@localhost:5432/python_learning_dev
REDIS_URL=redis://localhost:6379

# Supabase Configuration (Development)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
SUPABASE_SERVICE_KEY=your-service-key-here

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-for-development-only

# Stripe Configuration (Test Mode)
STRIPE_PUBLIC_KEY=pk_test_your_stripe_public_key
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key

# Code Execution Configuration
PYTHON_EXECUTOR_URL=http://localhost:5000
DOCKER_ENABLED=false

# Frontend Configuration
VITE_API_BASE_URL=http://localhost:8080
VITE_AUTH_SERVICE_URL=http://localhost:8081
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
VITE_STRIPE_PUBLIC_KEY=pk_test_your_stripe_public_key

# API Service Configuration
API_PORT=8080
CORS_ORIGINS=http://localhost:3000,http://localhost:5173

# Auth Service Configuration
AUTH_PORT=8081
AUTH_SERVICE_URL=http://localhost:8081

# Executor Service Configuration
EXECUTOR_PORT=5000
MAX_EXECUTION_TIME=30
MAX_MEMORY_MB=128
EOF
    
    print_success "Environment file created at $workspace_dir/.env.local"
    print_warning "Please update the environment variables with your actual values"
}

# Create package.json for workspace management
create_workspace_package() {
    print_step "Creating workspace package.json..."
    
    local workspace_dir="$PROJECT_ROOT/workspace"
    
    cat > "$workspace_dir/package.json" << EOF
{
  "name": "python-learning-portal-workspace",
  "version": "1.0.0",
  "description": "Development workspace for Python Learning Portal microservices",
  "scripts": {
    "dev": "concurrently \"npm run dev:shared\" \"npm run dev:api\" \"npm run dev:auth\" \"npm run dev:frontend\" \"npm run dev:executor\"",
    "dev:shared": "cd python-learning-shared && npm run dev",
    "dev:frontend": "cd python-learning-frontend && npm run dev",
    "dev:api": "cd python-learning-api && npm run dev",
    "dev:auth": "cd python-learning-auth && npm run dev",
    "dev:executor": "cd python-learning-executor && python app.py",
    "build": "npm run build:shared && npm run build:frontend && npm run build:api && npm run build:auth",
    "build:shared": "cd python-learning-shared && npm run build",
    "build:frontend": "cd python-learning-frontend && npm run build",
    "build:api": "cd python-learning-api && npm run build",
    "build:auth": "cd python-learning-auth && npm run build",
    "test": "npm run test:shared && npm run test:frontend && npm run test:api && npm run test:auth && npm run test:executor",
    "test:shared": "cd python-learning-shared && npm test",
    "test:frontend": "cd python-learning-frontend && npm test",
    "test:api": "cd python-learning-api && npm test",
    "test:auth": "cd python-learning-auth && npm test",
    "test:executor": "cd python-learning-executor && python -m pytest",
    "docker:up": "docker-compose -f ../docker-compose.local.yml up -d",
    "docker:down": "docker-compose -f ../docker-compose.local.yml down",
    "docker:logs": "docker-compose -f ../docker-compose.local.yml logs -f"
  },
  "devDependencies": {
    "concurrently": "^8.2.0"
  }
}
EOF
    
    cd "$workspace_dir"
    npm install
    
    print_success "Workspace package.json created and dependencies installed"
}

# Display final instructions
show_instructions() {
    print_success "🎉 Local development environment setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Update environment variables in workspace/.env.local"
    echo "2. Start the local database and Redis:"
    echo "   cd workspace && npm run docker:up"
    echo ""
    echo "3. Start all services in development mode:"
    echo "   cd workspace && npm run dev"
    echo ""
    echo "4. Access the application:"
    echo "   - Frontend: http://localhost:3000"
    echo "   - API Service: http://localhost:8080"
    echo "   - Auth Service: http://localhost:8081"
    echo "   - Executor Service: http://localhost:5000"
    echo ""
    echo "5. Run tests:"
    echo "   cd workspace && npm run test"
    echo ""
    echo "6. View Docker logs:"
    echo "   cd workspace && npm run docker:logs"
    echo ""
    echo "For more information, check the README files in each service directory."
}

# Main execution
main() {
    echo "🚀 Setting up Python Learning Portal microservices development environment"
    echo ""
    
    check_prerequisites
    setup_repositories
    install_dependencies
    create_env_files
    create_workspace_package
    show_instructions
}

# Run main function
main "$@"