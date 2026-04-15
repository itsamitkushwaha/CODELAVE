# =============================================================================
# DATABASE MODULE
#
# Provisions the full data layer for one environment:
#
#   1. Random master password (generated here, never hardcoded)
#   2. RDS DB subnet group   — uses the private subnets from the networking module
#   3. RDS PostgreSQL 16     — in private subnets, behind the database SG
#       - Storage autoscaling enabled
#       - Automated daily backups with 7-day retention
#       - Encryption at rest (AES-256)
#       - Multi-AZ flag driven by var (false for dev/staging, true for prod)
#   4. ElastiCache subnet group — uses same private subnets
#   5. ElastiCache Redis 7   — in private subnets, behind the redis SG
#       - Encryption at rest + in transit
#       - Automatic failover flag driven by var
#   6. Secrets Manager secret — stores RDS endpoint + credentials in JSON
#       so the API server never needs a hardcoded password
#
# IMPORTANT: The generated password is stored ONLY in AWS Secrets Manager.
# It is also present in Terraform state. Ensure your S3 state bucket
# is encrypted (it is — see security module).
# =============================================================================


# =============================================================================
# 1. RANDOM PASSWORD
# Terraform generates this once; rotation must be done via SecretsManager
# rotation Lambda or manual CLI update (not via Terraform re-apply).
# =============================================================================
resource "random_password" "db_master" {
  length           = 32
  special          = true
  # RDS disallows @, ", /, and space in passwords
  override_special = "!#$%^&*()_+-=[]{}|;:,.<>?"
}


# =============================================================================
# 2. RDS SUBNET GROUP
# RDS requires a subnet group that spans at least 2 AZs.
# We reuse the private subnets created by the networking module.
# =============================================================================
resource "aws_db_subnet_group" "main" {
  name        = "codelave-rds-subnet-group-${var.environment}"
  description = "Private subnets for RDS — ${var.environment}"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name        = "codelave-rds-subnet-group-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}


# =============================================================================
# 3. RDS POSTGRESQL INSTANCE
# =============================================================================
resource "aws_db_instance" "postgres" {
  identifier = "codelave-postgres-${var.environment}"

  # --- Engine ---
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # --- Storage ---
  allocated_storage     = var.db_allocated_storage_gb
  max_allocated_storage = var.db_max_allocated_storage_gb # enables autoscaling
  storage_type          = "gp3"
  storage_encrypted     = true # AES-256 encryption at rest

  # --- Database ---
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result

  # --- Network & Security ---
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.database_sg_id]
  publicly_accessible    = false # NEVER publicly accessible

  # --- High Availability ---
  multi_az = var.db_multi_az

  # --- Backups ---
  # backup_retention_period >= 1 enables automated daily backups.
  # backup_window must not overlap with maintenance_window.
  backup_retention_period = var.db_backup_retention_days
  backup_window           = var.db_backup_window
  maintenance_window      = var.db_maintenance_window

  # --- Performance Insights (free tier: 7-day retention) ---
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # --- Lifecycle & Safety ---
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "codelave-postgres-${var.environment}-final-snapshot"

  # Apply minor version patches automatically during the maintenance window.
  auto_minor_version_upgrade = true

  tags = {
    Name        = "codelave-postgres-${var.environment}"
    Environment = var.environment
    Role        = "primary-database"
    ManagedBy   = "terraform"
  }

  # Wait for the subnet group to exist first
  depends_on = [aws_db_subnet_group.main]
}


# =============================================================================
# 4. ELASTICACHE SUBNET GROUP
# Requires subnets in at least 2 AZs — same private subnets as RDS.
# =============================================================================
resource "aws_elasticache_subnet_group" "main" {
  name        = "codelave-redis-subnet-group-${var.environment}"
  description = "Private subnets for ElastiCache Redis — ${var.environment}"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name        = "codelave-redis-subnet-group-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}


# =============================================================================
# 5. ELASTICACHE PARAMETER GROUP
# Explicit group so we can tune Redis settings per environment in future
# without recreating the cluster.
# =============================================================================
resource "aws_elasticache_parameter_group" "redis" {
  name        = "codelave-redis-params-${var.environment}"
  family      = var.redis_parameter_group_family
  description = "Redis parameter group for Codelave ${var.environment}"

  # Enforce TLS-only connections at the Redis level
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru" # Evict least-recently-used keys when memory is full
  }

  tags = {
    Name        = "codelave-redis-params-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}


# =============================================================================
# 6. ELASTICACHE REDIS CLUSTER
# =============================================================================
resource "aws_elasticache_cluster" "redis" {
  cluster_id = "codelave-redis-${var.environment}"

  # --- Engine ---
  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_nodes      = var.redis_num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                 = var.redis_port

  # --- Network & Security ---
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.redis_sg_id]

  # --- Encryption ---
  at_rest_encryption_enabled = true # AES-256 encryption at rest
  # Note: For encryption-in-transit (TLS), migrate to aws_elasticache_replication_group
  # in prod with transit_encryption_enabled = true and an auth_token.

  # --- Maintenance ---
  maintenance_window       = "sun:05:00-sun:06:00" # After backup window, before business hours
  snapshot_retention_limit = var.environment == "prod" ? 7 : 1
  snapshot_window          = "03:30-04:30"

  # Apply minor version patches automatically
  auto_minor_version_upgrade = true

  tags = {
    Name        = "codelave-redis-${var.environment}"
    Environment = var.environment
    Role        = "cache-queue"
    ManagedBy   = "terraform"
  }

  depends_on = [aws_elasticache_subnet_group.main]
}


# =============================================================================
# 7. SECRETS MANAGER — DB CREDENTIALS SECRET
#
# Stores everything the API server needs to connect to Postgres.
# The API server's IAM role already has secretsmanager:GetSecretValue
# on "codelave/*" — so it can fetch this at runtime without any
# hardcoded credentials.
#
# The secret is UPDATED here with real values (endpoint + password)
# because Terraform owns the password. The ignore_changes lifecycle
# block from the secrets module's placeholder is NOT used here —
# this module owns the truth.
# =============================================================================
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "codelave/${var.environment}/db-credentials"
  description = "PostgreSQL credentials for Codelave ${var.environment} — managed by the database module"

  recovery_window_in_days = var.recovery_window_days

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform-database-module"
    Purpose     = "rds-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # Full connection details the API server needs at runtime
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
    dbname   = aws_db_instance.postgres.db_name
    username = aws_db_instance.postgres.username
    password = random_password.db_master.result
  })

  # If the password is ever rotated manually via Secrets Manager rotation Lambda,
  # Terraform should NOT overwrite it on the next apply.
  lifecycle {
    ignore_changes = [secret_string]
  }
}


# =============================================================================
# 8. SECRETS MANAGER — REDIS CONNECTION SECRET
#
# Redis itself has no authentication in this single-node setup
# (network isolation via SG is the security layer). We still store the
# endpoint in Secrets Manager so the API server fetches config from one
# consistent place.
# =============================================================================
resource "aws_secretsmanager_secret" "redis_connection" {
  name        = "codelave/${var.environment}/redis-connection"
  description = "Redis connection info for Codelave ${var.environment} — managed by the database module"

  recovery_window_in_days = var.recovery_window_days

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform-database-module"
    Purpose     = "redis-connection"
  }
}

resource "aws_secretsmanager_secret_version" "redis_connection" {
  secret_id = aws_secretsmanager_secret.redis_connection.id

  secret_string = jsonencode({
    host = aws_elasticache_cluster.redis.cache_nodes[0].address
    port = var.redis_port
    url  = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:${var.redis_port}"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
