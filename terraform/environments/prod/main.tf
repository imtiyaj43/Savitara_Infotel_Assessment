# Production Environment Root Module
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "production"
      ManagedBy   = "Terraform"
      Compliance  = "PCI-DSS-Ready"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# 1. Multi-AZ Networking with Redundant NAT Gateways
module "vpc" {
  source = "../../modules/vpc"

  project_name             = var.project_name
  environment              = "prod"
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  single_nat_gateway       = false # Dedicated NAT GW per AZ for production fault-tolerance
}

module "security_groups" {
  source = "../../modules/security_groups"

  project_name = var.project_name
  environment  = "prod"
  vpc_id       = module.vpc.vpc_id
  app_port     = var.app_port
}

module "s3" {
  source = "../../modules/s3"

  project_name           = var.project_name
  environment            = "prod"
  alb_log_retention_days = 90 # Production compliance audit retention
}

module "secrets" {
  source = "../../modules/secrets"

  project_name = var.project_name
  environment  = "prod"
  db_username  = var.db_username
  db_name      = var.db_name
  db_port      = 3306
  db_host      = module.rds.db_address
}

# 2. Production RDS MySQL with Multi-AZ Standby & Automated Backups
module "rds" {
  source = "../../modules/rds"

  project_name            = var.project_name
  environment             = "prod"
  subnet_ids              = module.vpc.private_db_subnet_ids
  rds_security_group_id   = module.security_groups.rds_security_group_id
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = module.secrets.generated_password
  db_instance_class       = "db.t3.small"
  multi_az                = true # Multi-AZ High Availability
  backup_retention_period = 14
  deletion_protection     = true
  skip_final_snapshot     = false
}

module "iam" {
  source = "../../modules/iam"

  project_name               = var.project_name
  environment                = "prod"
  db_secret_arn              = module.secrets.secret_arn
  app_storage_bucket_arn     = module.s3.app_storage_bucket_arn
  create_github_oidc_role    = var.create_github_oidc_role
  create_oidc_provider       = var.create_oidc_provider
  existing_oidc_provider_arn = var.existing_oidc_provider_arn
  github_repo                = var.github_repo
}

module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = "prod"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  app_port              = var.app_port
  health_check_path     = "/health"
  acm_certificate_arn   = var.acm_certificate_arn
  access_logs_bucket    = module.s3.alb_logs_bucket_id
  enable_access_logs    = true
}

# 3. Production Auto Scaling across AZs
module "asg" {
  source = "../../modules/asg"

  project_name           = var.project_name
  environment            = "prod"
  aws_region             = var.aws_region
  instance_type          = "t3.small"
  instance_profile_name  = module.iam.ec2_instance_profile_name
  ec2_security_group_id  = module.security_groups.ec2_security_group_id
  private_app_subnet_ids = module.vpc.private_app_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  app_port               = var.app_port
  db_secret_name         = module.secrets.secret_name
  app_storage_bucket     = module.s3.app_storage_bucket_id
  min_size               = 2
  max_size               = 6
  desired_capacity       = 2
  target_cpu_utilization = 60.0
}
