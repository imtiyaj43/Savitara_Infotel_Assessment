# End-to-End Deployment Guide

## 1. Prerequisites

Before deploying the infrastructure, ensure you have the following installed:
- **Terraform CLI**: `>= 1.5.0` ([Install Guide](https://developer.hashicorp.com/terraform/install))
- **AWS CLI**: `>= 2.0` ([Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **Git**: `>= 2.30`
- **Python 3**: `>= 3.9` (for automated validation scripts)
- An active AWS Account with permissions to provision VPC, EC2, RDS, IAM, S3, Secrets Manager, and ALB resources.

Configure your local AWS credentials:
```bash
aws configure
# Enter AWS Access Key ID, Secret Access Key, and default region (e.g., us-east-1)
```

---

## 2. Deployment Method 1: Local CLI (Recommended for Assessment Evaluation)

This method deploys the complete infrastructure locally in your AWS environment within minutes.

### Step 1: Clone the Repository
```bash
git clone https://github.com/<your-username>/savitara-infotel-aws.git
cd savitara-infotel-aws
```

### Step 2: Configure Terraform Variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```
Edit `terraform.tfvars` if you wish to customize parameters (defaults are already tuned for cost-efficiency using `t3.micro` and `single_nat_gateway = true`).

### Step 3: Initialize Terraform
```bash
terraform init
```

### Step 4: Preview Execution Plan
```bash
terraform plan
```
Review the proposed changes:
- `aws_vpc`, `aws_subnet` (6 subnets across 2 AZs)
- `aws_internet_gateway`, `aws_nat_gateway`, `aws_eip`
- `aws_security_group` (ALB, EC2, RDS)
- `aws_s3_bucket` (ALB logs, App storage)
- `aws_secretsmanager_secret` & `aws_secretsmanager_secret_version`
- `aws_db_instance` (RDS MySQL 8.0)
- `aws_launch_template` & `aws_autoscaling_group`
- `aws_lb`, `aws_lb_target_group`, `aws_lb_listener` (HTTP 80 & HTTPS 443)
- `aws_iam_role` & `aws_iam_instance_profile`

### Step 5: Provision Infrastructure
```bash
terraform apply -auto-approve
```
*Note: RDS MySQL instance creation typically takes 4–7 minutes.*

### Step 6: Review Outputs
Upon successful completion, Terraform displays:
```text
Apply complete! Resources: 38 added, 0 changed, 0 destroyed.

Outputs:
alb_dns_name = "savitara-dev-alb-123456789.us-east-1.elb.amazonaws.com"
application_url = "https://savitara-dev-alb-123456789.us-east-1.elb.amazonaws.com"
health_check_url = "https://savitara-dev-alb-123456789.us-east-1.elb.amazonaws.com/health"
rds_endpoint = "savitara-dev-mysql.xxxxxx.us-east-1.rds.amazonaws.com:3306"
secrets_manager_secret_name = "savitara-dev-db-credentials-xxxx"
autoscaling_group_name = "savitara-dev-asg-xxxx"
alb_logs_bucket = "savitara-dev-alb-logs-xxxx"
app_storage_bucket = "savitara-dev-app-storage-xxxx"
```

---

## 3. Deployment Method 2: Automated CI/CD (GitHub Actions)

### Step 1: Bootstrap Remote State & DynamoDB Locking
```bash
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
```
Note the generated S3 bucket name and DynamoDB table name from outputs.

### Step 2: Configure Remote State in Root Module
Rename `terraform/backend.tf.example` to `terraform/backend.tf` and paste your bucket name:
```hcl
terraform {
  backend "s3" {
    bucket         = "savitara-terraform-state-<ACCOUNT_ID>"
    key            = "savitara/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "savitara-terraform-locks"
    encrypt        = true
  }
}
```

### Step 3: Configure GitHub Secrets and Variables
1. Go to your repository on GitHub.
2. Navigate to **Settings > Secrets and variables > Actions**.
3. **Repository Secrets**:
   - `AWS_ROLE_ARN`: Value from `module.iam.github_actions_role_arn` (or run `./scripts/setup_oidc_role.sh`).
4. **Repository Variables**:
   - `AWS_REGION`: `us-east-1`
   - `TF_STATE_BUCKET`: `savitara-terraform-state-<ACCOUNT_ID>`
   - `TF_STATE_DYNAMODB_TABLE`: `savitara-terraform-locks`

### Step 4: Push to Main Branch
```bash
git add .
git commit -m "feat: complete infrastructure and CI/CD configuration"
git push origin main
```
Observe the execution under the **Actions** tab on GitHub. The workflow will automatically lint, scan, plan, and apply the infrastructure.

---

## 4. End-to-End Application Verification

Once deployed, allow 2–3 minutes for the EC2 Auto Scaling instances to complete user data initialization and register as `healthy` with the ALB Target Group.

### Verification Using the Automated Validation Script
Run the included Python verification suite:
```bash
python scripts/validate_deployment.py <ALB_DNS_NAME>
```

Expected output:
```text
======================================================================
 VALIDATING DEPLOYMENT FOR HOST: savitara-dev-alb-xxxx.us-east-1.elb.amazonaws.com
======================================================================

[TEST 1] Testing HTTP -> HTTPS 301 Redirect: http://savitara-dev-alb-xxxx...
  Status Code: 301
  Redirect Location: https://savitara-dev-alb-xxxx...
  ==> PASSED: HTTP correctly redirected to HTTPS 301.

[TEST] ALB Target Group Health Check: https://savitara-dev-alb-xxxx.../health
  Status Code: 200 (Latency: 45.2ms)
  Response Body: {
    "status": "healthy",
    "service": "savitara-infotel-api",
    "uptime_seconds": 128,
    "timestamp": "2026-10-06T17:05:00.000Z"
  }
  ==> PASSED: ALB Target Group Health Check

[TEST] Main Architecture Dashboard: https://savitara-dev-alb-xxxx.../
  Status Code: 200 (Latency: 62.1ms)
  Response Body: {
    "project": "Savitara Infotel - DevOps Practical Task",
    "status": "OPERATIONAL",
    "architecture": { ... },
    "runtime": {
      "is_ec2": true,
      "instance_id": "i-0a1b2c3d4e5f67890",
      "availability_zone": "us-east-1a",
      "private_ip": "10.0.11.45",
      "imds_version": "IMDSv2"
    },
    "database": {
      "connected": true,
      "server_time": "2026-10-06 17:05:00",
      "engine_version": "8.0.35"
    }
  }
  ==> PASSED: Main Architecture Dashboard

[TEST] RDS Database Connectivity: https://savitara-dev-alb-xxxx.../db-check
  Status Code: 200 (Latency: 18.4ms)
  ==> PASSED: RDS Database Connectivity

======================================================================
 VALIDATION SUMMARY
======================================================================
  HTTP -> HTTPS 301 Redirect               : PASS [OK]
  /health Endpoint                         : PASS [OK]
  / Endpoint                               : PASS [OK]
  /db-check Endpoint                       : PASS [OK]
  /info Endpoint                           : PASS [OK]
======================================================================
 ALL END-TO-END VERIFICATION CHECKS PASSED SUCCESSFULLY! 🚀
```

---

## 5. Teardown & Resource Cleanup

To prevent unnecessary AWS cloud costs after evaluation:

```bash
cd terraform
terraform destroy -auto-approve
```

If you provisioned the bootstrap remote state bucket:
```bash
cd terraform/bootstrap
terraform destroy -auto-approve
```
All resources—including RDS MySQL, EC2 ASG, ALB, NAT Gateway, EIPs, and S3 buckets—will be completely removed.
