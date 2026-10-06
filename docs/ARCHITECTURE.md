# System Architecture Specification

## 1. Executive Summary

This document details the architectural design for the **Savitara Infotel AWS Infrastructure & CI/CD Deployment**. The system implements an enterprise-grade, 3-tier, multi-Availability Zone (Multi-AZ) architecture using Infrastructure as Code (Terraform) and automated GitOps CI/CD (GitHub Actions via AWS IAM OIDC).

```
                      +------------------------------------------+
                      |         Internet / End Users             |
                      +------------------------------------------+
                                           |
                                    HTTPS :443 (TLS 1.3)
                                           v
+------------------------------------------------------------------------------------+
| AWS Cloud (us-east-1)                                                              |
|                                                                                    |
| +--------------------------------------------------------------------------------+ |
| | VPC: 10.0.0.0/16                                                               | |
| |                                                                                | |
| |  [ Internet Gateway ]                                                          | |
| |           |                                                                    | |
| |  =========+==================================================================  | |
| |  TIER 1: PUBLIC SUBNETS (ALB & NAT Gateways)                                   | |
| |  ----------------------------------------------------------------------------  | |
| |   us-east-1a: 10.0.1.0/24                     us-east-1b: 10.0.2.0/24          | |
| |   +----------------------------+             +----------------------------+    | |
| |   | Application Load Balancer  |             | ALB Passive Listener Node  |    | |
| |   | Port 80 (HTTP 301 Redir)   |             | ACM Certificate Attached   |    | |
| |   | Port 443 (HTTPS Listener)  |             | Access Logs -> S3 Bucket   |    | |
| |   | NAT Gateway 1 (Static EIP) |             | (Optional Multi-AZ NAT GW) |    | |
| |   +----------------------------+             +----------------------------+    | |
| |           |                                                |                   | |
| |  =========+================================================+=================  | |
| |  TIER 2: PRIVATE APPLICATION SUBNETS (EC2 Auto Scaling Group)                  | |
| |  ----------------------------------------------------------------------------  | |
| |   us-east-1a: 10.0.11.0/24                    us-east-1b: 10.0.12.0/24         | |
| |   +----------------------------+             +----------------------------+    | |
| |   | EC2 Node 1 (ASG Instance)  |             | EC2 Node 2 (ASG Instance)  |    | |
| |   | Node.js Express API :8080  |             | Node.js Express API :8080  |    | |
| |   | Amazon Linux 2023, IMDSv2  |             | Amazon Linux 2023, IMDSv2  |    | |
| |   | IAM Profile / Zero SSH     |             | IAM Profile / Zero SSH     |    | |
| |   +----------------------------+             +----------------------------+    | |
| |           |                                                |                   | |
| |  =========+================================================+=================  | |
| |  TIER 3: PRIVATE DATABASE SUBNETS (Amazon RDS MySQL 8.0)                       | |
| |  ----------------------------------------------------------------------------  | |
| |   us-east-1a: 10.0.21.0/24                    us-east-1b: 10.0.22.0/24         | |
| |   +----------------------------+             +----------------------------+    | |
| |   | Amazon RDS MySQL (Primary) |  Replicate  | Amazon RDS MySQL (Standby) |    | |
| |   | Port 3306 (From EC2-SG)    |<----------->| Isolated Subnet Group      |    | |
| |   | Encrypted gp3 Storage      |             | Zero Outbound / Zero NAT   |    | |
| |   +----------------------------+             +----------------------------+    | |
| +--------------------------------------------------------------------------------+ |
+------------------------------------------------------------------------------------+
```

---

## 2. Network Topology & Subnet Allocation

The VPC utilizes the `10.0.0.0/16` CIDR block partitioned into three distinct tiers across two Availability Zones (`us-east-1a` and `us-east-1b`):

| Subnet Name | CIDR Block | Availability Zone | Tier | Purpose | Internet Route |
|---|---|---|---|---|---|
| `public-subnet-1` | `10.0.1.0/24` | `us-east-1a` | Public | ALB Ingress, NAT Gateway | `0.0.0.0/0` -> Internet Gateway |
| `public-subnet-2` | `10.0.2.0/24` | `us-east-1b` | Public | ALB Ingress | `0.0.0.0/0` -> Internet Gateway |
| `private-app-subnet-1` | `10.0.11.0/24` | `us-east-1a` | Private App | EC2 ASG Instances | `0.0.0.0/0` -> NAT Gateway |
| `private-app-subnet-2` | `10.0.12.0/24` | `us-east-1b` | Private App | EC2 ASG Instances | `0.0.0.0/0` -> NAT Gateway |
| `private-db-subnet-1` | `10.0.21.0/24` | `us-east-1a` | Private DB | RDS MySQL Primary | Isolated (No Internet / NAT route) |
| `private-db-subnet-2` | `10.0.22.0/24` | `us-east-1b` | Private DB | RDS MySQL Standby | Isolated (No Internet / NAT route) |

### Routing Table Strategy
1. **Public Route Table**: Associates with `public-subnet-1` and `public-subnet-2`. Contains a default route `0.0.0.0/0` pointed to the Internet Gateway (`igw-xxxx`).
2. **Private App Route Table**: Associates with `private-app-subnet-1` and `private-app-subnet-2`. Contains a default route `0.0.0.0/0` pointed to the NAT Gateway (`nat-xxxx`).
3. **Private DB Route Table**: Associates with `private-db-subnet-1` and `private-db-subnet-2`. Contains **no default internet or NAT gateway route**. Strictly restricted to intra-VPC local routing (`10.0.0.0/16 -> local`).

---

## 3. Security Group Rules (Least Privilege)

Firewalls are modeled at the network interface layer enforcing explicit least privilege:

```
[ Internet: 0.0.0.0/0 ]
        |
        | TCP 80, 443
        v
+------------------+
|      alb-sg      |
+------------------+
        |
        | TCP 8080 (App Port) ONLY
        v
+------------------+
|      ec2-sg      |
+------------------+
        |
        | TCP 3306 (MySQL) ONLY
        v
+------------------+
|      rds-sg      |
+------------------+
```

### Detailed Matrix

| Security Group | Direction | Protocol | Port | Source / Destination | Description |
|---|---|---|---|---|---|
| `alb-sg` | Ingress | TCP | 80 | `0.0.0.0/0` | Inbound HTTP for 301 redirection to HTTPS |
| `alb-sg` | Ingress | TCP | 443 | `0.0.0.0/0` | Inbound secure HTTPS client traffic |
| `alb-sg` | Egress | TCP | 8080 | `ec2-sg` (ID reference) | Target Group forwarding to backend EC2 instances |
| `ec2-sg` | Ingress | TCP | 8080 | `alb-sg` (ID reference) | **Only** accepts traffic routed through the ALB |
| `ec2-sg` | Egress | TCP | 3306 | `rds-sg` (ID reference) | Outbound queries to RDS MySQL database |
| `ec2-sg` | Egress | TCP | 443 | `0.0.0.0/0` (via NAT GW) | Outbound HTTPS for AWS APIs (Secrets Manager, S3, SSM) |
| `ec2-sg` | Egress | TCP | 80 | `0.0.0.0/0` (via NAT GW) | OS package updates (`dnf`) during cloud-init |
| `ec2-sg` | Egress | UDP/TCP | 53 | `0.0.0.0/0` (VPC DNS Resolver) | Outbound DNS resolution for AWS endpoints and package repos |
| `ec2-sg` | Egress | UDP | 123 | `0.0.0.0/0` (Amazon Time Sync) | NTP time synchronization via chrony |
| `rds-sg` | Ingress | TCP | 3306 | `ec2-sg` (ID reference) | **Only** accepts MySQL traffic from application instances |
| `rds-sg` | Egress | - | - | None | RDS does not initiate outbound connections |

> **Zero SSH Exposure**: Inbound TCP port 22 is completely omitted. EC2 administration is handled through AWS Systems Manager (SSM) Session Manager.

---

## 4. Compute & Auto Scaling Architecture

### EC2 Launch Template Specifications
- **Operating System**: Amazon Linux 2023 (AMI dynamically discovered via `al2023-ami-2023.*-x86_64`).
- **Instance Type**: `t3.micro` (Free-tier eligible, burstable CPU).
- **Metadata Protection**: **IMDSv2 Enforced** (`http_tokens = "required"`, `http_put_response_hop_limit = 1`). Prevents SSRF credential theft.
- **Root Block Device**: 20 GB gp3 volume, `encrypted = true` using default AWS managed KMS key, `delete_on_termination = true`.
- **IAM Instance Profile**: Attached with least-privilege IAM policies for Secrets Manager, S3, and SSM.
- **User Data**: Automated cloud-init bootstrapping script:
  - Installs Node.js runtime and dependencies
  - Dynamically fetches database credentials from AWS Secrets Manager
  - Configures systemd service unit `savitara-app.service`
  - Verifies local health check on port `8080/health` before completing startup

### Auto Scaling Group (ASG) Configuration
- **Placement**: Multi-AZ across `private-app-subnet-1` and `private-app-subnet-2`.
- **Capacity**: Min: 2, Max: 4, Desired: 2.
- **Health Check Type**: `ELB` (Considers instances unhealthy if ALB health check fails).
- **Grace Period**: 300 seconds (allows cloud-init package installation to complete).
- **Scaling Policy**: Target Tracking Scaling Policy maintaining Average CPU Utilization at 70%.
- **Instance Refresh**: Rolling deployment strategy (`min_healthy_percentage = 50`) for zero-downtime rolling updates.

---

## 5. Database Architecture (RDS MySQL 8.0)

- **Engine**: MySQL Community Edition 8.0.
- **Subnet Group**: Private DB Subnet Group across isolated subnets in 2 Availability Zones.
- **Public Accessibility**: Explicitly disabled (`publicly_accessible = false`).
- **Storage**: gp3 volume (20 GB allocated, auto-scaling up to 50 GB).
- **Encryption**: KMS storage encryption enabled (`storage_encrypted = true`).
- **Credentials**: Master password dynamically generated via Terraform `random_password` (20 characters, URL-safe special chars) and stored in AWS Secrets Manager.
- **High Availability**: Multi-AZ synchronous standby replica configurable via variable `var.db_multi_az`.
- **Backup & Maintenance**: Automated daily snapshots retained for 1 to 14 days, automatic minor version updates enabled.

---

## 6. Load Balancing & SSL/TLS Termination

- **Load Balancer**: Internet-facing Application Load Balancer in public subnets across AZs.
- **Target Group**:
  - Protocol: HTTP on port 8080.
  - Health check path: `/health`.
  - Health check interval: 30 seconds; timeout: 5 seconds.
  - Healthy threshold: 2 consecutive successes; unhealthy threshold: 3 consecutive failures.
- **HTTP Listener (Port 80)**:
  - Rule: Default redirect action to HTTPS (Port 443) with status `HTTP_301 Moved Permanently`.
- **HTTPS Listener (Port 443)**:
  - Security Policy: `ELBSecurityPolicy-TLS13-1-2-2021-06` (enforces modern TLS 1.3 and TLS 1.2 with secure cipher suites).
  - SSL Certificate: ACM certificate managed via AWS Certificate Manager or self-signed fallback for zero-blocker evaluation.
  - Target: Forwards traffic to the backend Target Group.
- **Access Logs**: Delivered directly to dedicated encrypted S3 bucket `savitara-dev-alb-logs-xxxx` with 30-day lifecycle expiration.
