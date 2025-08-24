# Global variables for Python Learning Portal Infrastructure

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "python-learning-portal"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro" # Free tier eligible
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "python_learning_portal"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "portal_admin"
}

# ECS Configuration
variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks"
  type        = number
  default     = 256 # 0.25 vCPU - free tier friendly
}

variable "ecs_task_memory" {
  description = "Memory for ECS tasks"
  type        = number
  default     = 512 # 0.5 GB - free tier friendly
}

variable "api_desired_count" {
  description = "Desired number of API service tasks"
  type        = number
  default     = 1
}

variable "auth_desired_count" {
  description = "Desired number of Auth service tasks"
  type        = number
  default     = 1
}

# Frontend Configuration
variable "frontend_domain" {
  description = "Domain name for frontend"
  type        = string
  default     = ""
}

variable "api_domain" {
  description = "Domain name for API"
  type        = string
  default     = ""
}

# Redis Configuration
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro" # Free tier eligible
}

variable "redis_num_cache_nodes" {
  description = "Number of Redis cache nodes"
  type        = number
  default     = 1
}

# Monitoring and Logging
variable "enable_container_insights" {
  description = "Enable ECS Container Insights"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch logs retention period in days"
  type        = number
  default     = 7
}

# Security
variable "enable_waf" {
  description = "Enable AWS WAF for ALB"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open to internet - restrict in production
}

# Cost Optimization
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway (costs money)"
  type        = bool
  default     = false # Use NAT Instance for free tier
}

variable "use_spot_instances" {
  description = "Use EC2 Spot Instances for cost savings"
  type        = bool
  default     = false
}

# Auto Scaling
variable "api_min_capacity" {
  description = "Minimum number of API service tasks"
  type        = number
  default     = 1
}

variable "api_max_capacity" {
  description = "Maximum number of API service tasks"
  type        = number
  default     = 10
}

variable "auth_min_capacity" {
  description = "Minimum number of Auth service tasks"
  type        = number
  default     = 1
}

variable "auth_max_capacity" {
  description = "Maximum number of Auth service tasks"
  type        = number
  default     = 5
}

# Tags
variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "python-learning-portal"
    ManagedBy = "terraform"
  }
}

# Secrets
variable "supabase_url" {
  description = "Supabase project URL"
  type        = string
  sensitive   = true
  default     = ""
}

variable "supabase_anon_key" {
  description = "Supabase anonymous key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "stripe_publishable_key" {
  description = "Stripe publishable key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "stripe_secret_key" {
  description = "Stripe secret key"
  type        = string
  sensitive   = true
  default     = ""
}