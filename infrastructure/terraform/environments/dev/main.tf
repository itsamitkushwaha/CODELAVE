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
  recovery_window_days = 7 # Shorter window for dev — allows faster cleanup
}

# -----------------------------------------------------------------------------
# Data Layer — PostgreSQL (RDS) + Redis (ElastiCache)
# Dev uses the smallest instance sizes and no Multi-AZ to minimise cost.
# Backups are still enabled (7-day retention) so the pattern is consistent
# with staging and prod.
# -----------------------------------------------------------------------------
module "database" {
  source = "../../modules/database"

  environment        = var.environment
  private_subnet_ids = module.networking.private_subnet_ids
  database_sg_id     = module.security_groups.database_sg_id
  redis_sg_id        = module.security_groups.redis_sg_id

  # --- RDS PostgreSQL (dev: smallest class, no Multi-AZ) ---
  db_instance_class           = var.db_instance_class
  db_allocated_storage_gb     = var.db_allocated_storage_gb
  db_max_allocated_storage_gb = 50 # cap autoscaling in dev
  db_multi_az                 = false
  db_deletion_protection      = false
  db_skip_final_snapshot      = true
  db_backup_retention_days    = 7

  # --- ElastiCache Redis (dev: single cheapest node) ---
  redis_node_type       = var.redis_node_type
  redis_num_cache_nodes = 1

  # --- Secrets ---
  recovery_window_days = 7
}
