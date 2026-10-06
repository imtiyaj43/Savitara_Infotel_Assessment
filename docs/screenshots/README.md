# Configuration & Deployment Screenshots Guide

This guide details the exact screenshots required for the **Savitara Infotel DevOps Technical Assessment** submission, along with the corresponding AWS Console navigation paths and AWS CLI verification commands.

> [!TIP]
> Capture each screenshot when deploying to your AWS account or during your CI/CD pipeline run. Save the image files in this folder (`docs/screenshots/`) matching the filenames below.

---

## Required Screenshots Checklist

### 1. AWS Networking (VPC, Subnets & Route Tables)
- **Target Filename**: `01_aws_vpc_subnets.png`
- **Console Path**: AWS Console ➔ **VPC** ➔ **Subnets**
- **What to show**:
  - Filter by VPC: `savitara-dev-vpc`
  - 6 Subnets visible (2 Public, 2 Private App, 2 Private DB across 2 AZs).
  - Subnet tags showing `Tier = Public`, `Tier = Private-App`, `Tier = Private-DB`.
- **AWS CLI Verification Command**:
  ```bash
  aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$(terraform -chdir=terraform output -raw vpc_id)" \
    --query "Subnets[*].{Name:Tags[?Key=='Name']|[0].Value, CIDR:CidrBlock, AZ:AvailabilityZone}" \
    --output table
  ```

---

### 2. NAT Gateway & Internet Gateway
- **Target Filename**: `02_nat_and_internet_gateway.png`
- **Console Path**: AWS Console ➔ **VPC** ➔ **NAT Gateways** & **Internet Gateways**
- **What to show**:
  - NAT Gateway in `Available` state with Elastic IP attached.
  - Internet Gateway attached to `savitara-dev-vpc`.
- **AWS CLI Verification Command**:
  ```bash
  aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$(terraform -chdir=terraform output -raw vpc_id)" \
    --output table
  ```

---

### 3. Application Load Balancer & HTTPS Listener
- **Target Filename**: `03_alb_https_listener.png`
- **Console Path**: AWS Console ➔ **EC2** ➔ **Load Balancers** ➔ Select `savitara-dev-alb`
- **What to show**:
  - DNS name of the ALB.
  - Listener tab showing:
    - **Port 80 (HTTP)**: 301 Redirect to HTTPS:443.
    - **Port 443 (HTTPS)**: Forward to target group `savitara-dev-tg` with SSL certificate attached.
  - Attributes tab showing **Access logs: Enabled** with target S3 bucket.
- **AWS CLI Verification Command**:
  ```bash
  aws elbv2 describe-listeners \
    --load-balancer-arn $(terraform -chdir=terraform output -raw alb_arn) \
    --output table
  ```

---

### 4. Target Group Health Checks
- **Target Filename**: `04_alb_target_group_healthy.png`
- **Console Path**: AWS Console ➔ **EC2** ➔ **Target Groups** ➔ Select `savitara-dev-tg`
- **What to show**:
  - Registered targets tab showing 2 EC2 instances with health status **`healthy`**.
  - Health check path set to `/health` with HTTP port 8080.
- **AWS CLI Verification Command**:
  ```bash
  aws elbv2 describe-target-health \
    --target-group-arn $(terraform -chdir=terraform output -raw target_group_arn) \
    --output table
  ```

---

### 5. EC2 Launch Template & Auto Scaling Group
- **Target Filename**: `05_asg_and_launch_template.png`
- **Console Path**: AWS Console ➔ **EC2** ➔ **Auto Scaling Groups**
- **What to show**:
  - Desired capacity: 2, Min: 2, Max: 4.
  - Instance count = 2 in `InService` lifecycle state across multiple AZs (`us-east-1a`, `us-east-1b`).
  - Target tracking CPU policy visible in the Automatic Scaling tab.
- **AWS CLI Verification Command**:
  ```bash
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names $(terraform -chdir=terraform output -raw autoscaling_group_name) \
    --query "AutoScalingGroups[0].{Name:AutoScalingGroupName, Instances:Instances[*].{Id:InstanceId, AZ:AvailabilityZone, Health:HealthStatus, State:LifecycleState}}" \
    --output json
  ```

---

### 6. RDS MySQL in Private Subnets
- **Target Filename**: `06_rds_mysql_private.png`
- **Console Path**: AWS Console ➔ **RDS** ➔ **Databases** ➔ Select `savitara-dev-mysql`
- **What to show**:
  - Status: `Available`.
  - Connectivity & security: **Publicly accessible: No**.
  - Subnet group spanning private DB subnets across 2 AZs.
  - Encryption: **Enabled** (KMS).
- **AWS CLI Verification Command**:
  ```bash
  aws rds describe-db-instances \
    --db-instance-identifier savitara-dev-mysql \
    --query "DBInstances[0].{ID:DBInstanceIdentifier, Status:DBInstanceStatus, Public:PubliclyAccessible, Engine:Engine, Encrypted:StorageEncrypted}" \
    --output table
  ```

---

### 7. AWS Secrets Manager
- **Target Filename**: `07_secrets_manager.png`
- **Console Path**: AWS Console ➔ **Secrets Manager** ➔ Select `savitara-dev-db-credentials-*`
- **What to show**:
  - Secret ARN, description, encryption key.
  - Secret value JSON schema containing `engine`, `host`, `port`, `username`, and `database` (with masked password).
- **AWS CLI Verification Command**:
  ```bash
  aws secretsmanager describe-secret \
    --secret-id $(terraform -chdir=terraform output -raw secrets_manager_secret_name) \
    --query "{Name:Name, ARN:ARN, LastRotatedDate:LastRotatedDate, Description:Description}" \
    --output table
  ```

---

### 8. S3 Buckets (ALB Logs & Application Storage)
- **Target Filename**: `08_s3_buckets_and_logs.png`
- **Console Path**: AWS Console ➔ **S3** ➔ Select `savitara-dev-alb-logs-*`
- **What to show**:
  - **Block Public Access**: All 4 checkboxes enabled (Yellow warning "Bucket and objects not public").
  - `alb-logs/` folder containing generated access log `.gz` files delivered by AWS ELB service.
- **AWS CLI Verification Command**:
  ```bash
  aws s3 ls "s3://$(terraform -chdir=terraform output -raw alb_logs_bucket)/alb-logs/" --recursive
  ```

---

### 9. GitHub Actions CI/CD Pipeline Execution
- **Target Filename**: `09_github_actions_workflow.png`
- **Console Path**: GitHub Repository ➔ **Actions** tab ➔ Select latest run
- **What to show**:
  - All four stages green (`Lint & Validate`, `Security Scan`, `Terraform Plan`, `Terraform Apply`).
  - GitHub Step Summary showing the published HTTPS URL and RDS endpoint.
  - OIDC authentication step showing successful AWS STS token assumption.

---

### 10. Live HTTPS Application Verification
- **Target Filename**: `10_live_application_response.png`
- **Browser / Terminal Path**: Open `https://<ALB_DNS_NAME>/` and `https://<ALB_DNS_NAME>/health`
- **What to show**:
  - JSON response showing `status: "healthy"` and `OPERATIONAL`.
  - Database status showing `connected: true` with MySQL server time and version.
  - Runtime metadata showing EC2 instance ID and Availability Zone.
- **Verification Command**:
  ```bash
  python scripts/validate_deployment.py <ALB_DNS_NAME>
  ```
