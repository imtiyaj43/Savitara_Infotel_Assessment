# Dev Environment Root Module
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
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "../../modules/vpc"

  project_name             = var.project_name
  environment              = "dev"
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  single_nat_gateway       = true # Cost optimization in Dev
}

module "security_groups" {
  source = "../../modules/security_groups"

  project_name = var.project_name
  environment  = "dev"
  vpc_id       = module.vpc.vpc_id
  app_port     = var.app_port
}

module "s3" {
  source = "../../modules/s3"

  project_name           = var.project_name
  environment            = "dev"
  alb_log_retention_days = 14
}

module "secrets" {
  source = "../../modules/secrets"

  project_name = var.project_name
  environment  = "dev"
  db_username  = var.db_username
  db_name      = var.db_name
  db_port      = 3306
  db_host      = module.rds.db_address
}

module "rds" {
  source = "../../modules/rds"

  project_name          = var.project_name
  environment           = "dev"
  subnet_ids            = module.vpc.private_db_subnet_ids
  rds_security_group_id = module.security_groups.rds_security_group_id
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = module.secrets.generated_password
  db_instance_class     = "db.t3.micro"
  multi_az              = false
}

module "iam" {
  source = "../../modules/iam"

  project_name               = var.project_name
  environment                = "dev"
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
  environment           = "dev"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  app_port              = var.app_port
  health_check_path     = "/health"
  acm_certificate_arn   = var.acm_certificate_arn
  access_logs_bucket    = module.s3.alb_logs_bucket_id
  enable_access_logs    = true
}

module "asg" {
  source = "../../modules/asg"

  project_name           = var.project_name
  environment            = "dev"
  aws_region             = var.aws_region
  instance_type          = "t3.micro"
  instance_profile_name  = module.iam.ec2_instance_profile_name
  ec2_security_group_id  = module.security_groups.ec2_security_group_id
  private_app_subnet_ids = module.vpc.private_app_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  app_port               = var.app_port
  db_secret_name         = module.secrets.secret_name
  app_storage_bucket     = module.s3.app_storage_bucket_id
  min_size               = 1
  max_size               = 2
  desired_capacity       = 1
  target_cpu_utilization = 70.0
}
