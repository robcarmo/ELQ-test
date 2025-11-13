locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr    = var.vpc_cidr
  name_prefix = local.name_prefix
  num_azs     = var.num_azs
  tags        = local.common_tags
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = var.ecr_repository_name
  scan_on_push    = true
  force_delete    = true
  tags            = local.common_tags
}

module "alb" {
  source = "./modules/alb"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  target_port        = var.container_port
  health_check_path  = "/health"
  tags               = local.common_tags
}

module "ecs" {
  source = "./modules/ecs"

  cluster_name           = var.ecs_cluster_name
  service_name           = var.ecs_service_name
  container_name         = var.container_name
  container_image        = var.container_image
  container_port         = var.container_port
  task_cpu               = var.task_cpu
  task_memory            = var.task_memory
  desired_count          = var.desired_count
  min_capacity           = var.min_capacity
  max_capacity           = var.max_capacity
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  alb_security_group_id  = module.alb.security_group_id
  target_group_arn       = module.alb.target_group_arn
  alb_listener_arn       = module.alb.listener_arn
  app_version            = var.app_version
  environment            = var.environment
  aws_region             = var.aws_region
  log_retention_days     = var.log_retention_days
  tags                   = local.common_tags
}
