# Cost Optimization & Sizing Strategy

## 1. Overview & Financial Consciousness

Cloud infrastructure costs often escalate due to unoptimized development configurations. This architecture applies cost-conscious engineering principles suited for development and assessment environments while providing production toggles for high-availability requirements.

---

## 2. Key Architectural Cost Optimizations

### 1. Single NAT Gateway in Development
- **AWS Cost Impact**: Each AWS NAT Gateway incurs ~\$0.045/hour plus data processing fees (~\$32.40/month per NAT Gateway).
- **Optimization**: The default development configuration sets `single_nat_gateway = true`, routing all private application subnets through one NAT Gateway.
- **Production Mode**: When deploying to production (`terraform/environments/prod`), `single_nat_gateway = false` creates a dedicated NAT Gateway per AZ to avoid cross-AZ dependency.

### 2. Right-Sized EC2 & RDS Instances
- **Compute**: Uses `t3.micro` instances (2 vCPUs, 1 GB RAM). Eligible for AWS Free Tier (750 hours/month).
- **Database**: Uses `db.t3.micro` instance class. Eligible for AWS Free Tier RDS MySQL.
- **Storage**: Uses `gp3` volumes. gp3 provides 3,000 IOPS and 125 MB/s throughput included in baseline pricing without paying extra for provisioned IOPS (`io1`/`io2`).

### 3. S3 Lifecycle Rules on Access Logs
- ALB access logs can accumulate gigabytes of request logs over time.
- Implemented `aws_s3_bucket_lifecycle_configuration` to automatically expire and delete logs older than 30 days in dev (90 days in prod), eliminating unbounded storage charges.

### 4. Auto Scaling Down to Minimum
- The Auto Scaling Group scales down to 1 or 2 instances during quiet hours via Target Tracking scaling policies.
- Deletion protection is parameterized (`var.deletion_protection`), allowing clean teardown during technical evaluation without manual console overrides.

---

## 3. Monthly Cost Estimation (us-east-1)

| Service Component | Configuration | Dev / Assessment Est. | Prod Multi-AZ Est. |
|---|---|---|---|
| **VPC & Subnets** | Custom VPC, 6 Subnets, IGW | \$0.00 | \$0.00 |
| **NAT Gateway** | 1 NAT GW (Dev) vs 2 NAT GWs (Prod) | ~\$32.40 / mo | ~\$64.80 / mo |
| **Elastic IP** | 1 EIP (Dev) vs 2 EIPs (Prod) | Included with NAT GW | Included with NAT GW |
| **Application Load Balancer** | 1 ALB (1 LCU baseline) | ~\$16.20 / mo | ~\$16.20 / mo |
| **EC2 Auto Scaling** | 2 x `t3.micro` (gp3 20GB) | ~\$15.20 / mo (Free-tier eligible) | ~\$30.40 / mo (`t3.small`) |
| **RDS MySQL 8.0** | `db.t3.micro` Single-AZ vs `db.t3.small` Multi-AZ | ~\$12.50 / mo (Free-tier eligible) | ~\$58.40 / mo |
| **AWS Secrets Manager** | 1 Secret, ~10,000 API calls | ~\$0.45 / mo | ~\$0.45 / mo |
| **Amazon S3 & Logs** | 2 Buckets (Storage + Logs &lt; 5GB) | ~\$0.15 / mo | ~\$0.50 / mo |
| **GitHub Actions CI/CD** | OIDC Role (Free), Ubuntu runner | \$0.00 | \$0.00 |
| **Estimated Total** | | **~\$76.90 / mo** | **~\$170.75 / mo** |

> *Note: In accounts within the 12-month AWS Free Tier, the EC2 and RDS instances are \$0.00, reducing the development cost to ~\$49/month.*

---

## 4. Immediate Teardown Command

To eliminate all costs after completing the assessment review:

```bash
cd terraform
terraform destroy -auto-approve
```
All billable resources are deleted cleanly within 5–8 minutes.
