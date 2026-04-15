module "networking" {
  source = "../../modules/networking"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "security_groups" {
  source = "../../modules/security-groups"

  vpc_id      = module.networking.vpc_id
  vpc_cidr    = module.networking.vpc_cidr
  environment = var.environment
}

module "secrets" {
  source = "../../modules/secrets"

  environment          = var.environment
  recovery_window_days = 30
}

# -----------------------------------------------------------------------------
# Data Layer — PostgreSQL (RDS) + Redis (ElastiCache)
# Prod uses Multi-AZ RDS for HA, deletion protection, a final snapshot on
# destroy, and larger instance/node sizes. Backups run for 7 days.
# -----------------------------------------------------------------------------
module "database" {
  source = "../../modules/database"

  environment        = var.environment
  private_subnet_ids = module.networking.private_subnet_ids
  database_sg_id     = module.security_groups.database_sg_id
  redis_sg_id        = module.security_groups.redis_sg_id

  # --- RDS PostgreSQL (prod: Multi-AZ, deletion protection, final snapshot) ---
  db_instance_class           = var.db_instance_class
  db_allocated_storage_gb     = var.db_allocated_storage_gb
  db_max_allocated_storage_gb = 500
  db_multi_az                 = true  # Auto-failover standby in second AZ
  db_deletion_protection      = true  # Prevent accidental destroy
  db_skip_final_snapshot      = false # Always take a snapshot before destroy
  db_backup_retention_days    = 7

  # --- ElastiCache Redis ---
  redis_node_type       = var.redis_node_type
  redis_num_cache_nodes = 1

  # --- Secrets ---
  recovery_window_days = 30
}
