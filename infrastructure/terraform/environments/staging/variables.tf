variable "aws_region" {
  description = "The AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the entire VPC (must be /16)"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for the two public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for the two private subnets (one per AZ)"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of two Availability Zones to spread subnets across"
  type        = list(string)
}

# --- Database ---

variable "db_instance_class" {
  description = "RDS PostgreSQL instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage_gb" {
  description = "Initial allocated storage for RDS in GB"
  type        = number
  default     = 20
}

# --- Redis ---

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}
