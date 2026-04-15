# =============================================================================
# DATABASE MODULE — VARIABLES
# =============================================================================

variable "environment" {
  description = "The deployment environment (dev, staging, prod)"
  type        = string
}


variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB and Redis subnet groups (must be in at least 2 AZs)"
  type        = list(string)
}

variable "database_sg_id" {
  description = "Security Group ID for the RDS PostgreSQL instance"
  type        = string
}

variable "redis_sg_id" {
  description = "Security Group ID for the ElastiCache Redis cluster"
  type        = string
}

# --- RDS PostgreSQL ---

variable "db_name" {
  description = "Name of the initial PostgreSQL database to create"
  type        = string
  default     = "codelave"
}

variable "db_username" {
  description = "Master username for the PostgreSQL instance"
  type        = string
  default     = "codelave_admin"
}

variable "db_instance_class" {
  description = "RDS instance class (e.g. db.t3.micro for dev, db.t3.small for prod)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage_gb" {
  description = "Initial allocated storage for RDS in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage_gb" {
  description = "Upper limit on storage autoscaling in GB. Set to 0 to disable autoscaling."
  type        = number
  default     = 100
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.3"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS (true for prod HA, false for dev/staging cost savings)"
  type        = bool
  default     = false
}

variable "db_backup_retention_days" {
  description = "Number of days to retain automated RDS backups (must be >= 1 to enable backups)"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "Preferred daily backup window in UTC (hh24:mi-hh24:mi). Must not overlap with maintenance_window."
  type        = string
  default     = "02:00-03:00"
}

variable "db_maintenance_window" {
  description = "Preferred weekly maintenance window (ddd:hh24:mi-ddd:hh24:mi). Must not overlap with backup_window."
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "db_deletion_protection" {
  description = "Enable deletion protection on the RDS instance (set true for prod)"
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on destroy. Set false for prod to preserve last backup."
  type        = bool
  default     = true
}

# --- ElastiCache Redis ---

variable "redis_node_type" {
  description = "ElastiCache node type (e.g. cache.t3.micro for dev, cache.t3.small for prod)"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of Redis cache nodes (use 1 for dev, 2+ for prod replication)"
  type        = number
  default     = 1
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_parameter_group_family" {
  description = "Redis parameter group family (must match engine version)"
  type        = string
  default     = "redis7"
}

variable "redis_port" {
  description = "Port Redis listens on"
  type        = number
  default     = 6379
}

variable "recovery_window_days" {
  description = "Number of days before a deleted secret is permanently destroyed"
  type        = number
  default     = 7
}
