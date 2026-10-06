# Query available AZs in current region
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. Networking Module (VPC, Subnets across AZs, IGW, NAT GW, Routing)
module "vpc" {
  source = "./modules/vpc"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  single_nat_gateway       = var.single_nat_gateway
}

# 2. Security Groups Module (Least Privilege rules for ALB, EC2, RDS)
module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  app_port     = var.app_port
}

# 3. S3 Buckets Module (ALB Access Logs & App Storage)
module "s3" {
  source = "./modules/s3"

  project_name           = var.project_name
  environment            = var.environment
  alb_log_retention_days = var.alb_log_retention_days
}

# 4. Secrets Module (Random Password & AWS Secrets Manager)
module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  environment  = var.environment
  db_username  = var.db_username
  db_name      = var.db_name
  db_port      = 3306
  db_host      = module.rds.db_address
}

# 5. RDS MySQL Module (Private Subnet Group, KMS encryption)
module "rds" {
  source = "./modules/rds"

  project_name          = var.project_name
  environment           = var.environment
  subnet_ids            = module.vpc.private_db_subnet_ids
  rds_security_group_id = module.security_groups.rds_security_group_id
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = module.secrets.generated_password
  db_instance_class     = var.db_instance_class
  multi_az              = var.db_multi_az
}

# 6. IAM Module (EC2 Instance Profile, Least-Privilege Policies, GitHub OIDC)
module "iam" {
  source = "./modules/iam"

  project_name               = var.project_name
  environment                = var.environment
  db_secret_arn              = module.secrets.secret_arn
  app_storage_bucket_arn     = module.s3.app_storage_bucket_arn
  create_github_oidc_role    = var.create_github_oidc_role
  create_oidc_provider       = var.create_oidc_provider
  existing_oidc_provider_arn = var.existing_oidc_provider_arn
  github_repo                = var.github_repo
}

# 7. Application Load Balancer Module (HTTPS 443, HTTP 80 301 redirect, ACM)
module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id
  app_port              = var.app_port
  health_check_path     = "/health"
  acm_certificate_arn   = var.acm_certificate_arn
  access_logs_bucket    = module.s3.alb_logs_bucket_id
  enable_access_logs    = var.enable_alb_access_logs
}

# 8. EC2 Auto Scaling Module (Launch Template, IMDSv2, gp3, user_data bootstrap)
module "asg" {
  source = "./modules/asg"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  instance_type          = var.instance_type
  instance_profile_name  = module.iam.ec2_instance_profile_name
  ec2_security_group_id  = module.security_groups.ec2_security_group_id
  private_app_subnet_ids = module.vpc.private_app_subnet_ids
  target_group_arn       = module.alb.target_group_arn
  app_port               = var.app_port
  db_secret_name         = module.secrets.secret_name
  app_storage_bucket     = module.s3.app_storage_bucket_id
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_desired_capacity
  target_cpu_utilization = var.target_cpu_utilization
}
