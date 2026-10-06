# Security & Compliance Specification

## 1. Security Overview

Security is designed into every layer of this infrastructure following the AWS Well-Architected Security Pillar and Center for Internet Security (CIS) AWS Foundations Benchmark.

```
+-------------------------------------------------------------------------------+
|                             SECURITY IN DEPTH                                  |
|                                                                               |
|  [ Perimeter ]    -> ALB Ingress Filtering, HTTPS/TLS 1.3, HTTP 301 Redirect  |
|  [ Network ]      -> Subnet Isolation (Public / Private App / Isolated DB)    |
|  [ Compute ]      -> IMDSv2 Required, Zero SSH Port 22, SSM Session Manager    |
|  [ Data ]         -> KMS Storage Encryption (gp3 / RDS), S3 SSE-AES256        |
|  [ Secrets ]      -> AWS Secrets Manager, Zero Hardcoded Secrets in Git       |
|  [ Identity ]     -> IAM Least Privilege, GitHub OIDC (No Static AWS Keys)    |
|  [ Auditability ] -> ALB Access Logs to S3, CloudWatch Logs, CloudTrail       |
+-------------------------------------------------------------------------------+
```

---

## 2. IAM Least-Privilege Architecture

### A. EC2 Application Role
The EC2 instances run with an IAM Instance Profile granting strictly required capabilities:

| Permission | Resource Scope | Purpose |
|---|---|---|
| `secretsmanager:GetSecretValue`<br/>`secretsmanager:DescribeSecret` | `arn:aws:secretsmanager:REGION:ACCOUNT:secret:savitara-dev-db-credentials-*` | Restricts access exclusively to the application database secret ARN. Instances cannot read other account secrets. |
| `s3:GetObject`<br/>`s3:PutObject`<br/>`s3:DeleteObject`<br/>`s3:ListBucket` | `arn:aws:s3:::savitara-dev-app-storage-*`<br/>`arn:aws:s3:::savitara-dev-app-storage-*/*` | Confined strictly to the application storage bucket. Cannot access ALB access logs or other infrastructure buckets. |
| `AmazonSSMManagedInstanceCore` | `*` (AWS Managed) | Enables Systems Manager Session Manager. Removes the need for inbound SSH keys or bastion hosts. |
| `logs:CreateLogGroup`<br/>`logs:PutLogEvents` | `arn:aws:logs:*:*:log-group:/aws/ec2/savitara*` | Streams application and system logs to Amazon CloudWatch Logs. |

### B. CI/CD: GitHub Actions OIDC Authentication
Long-lived AWS access keys (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) introduce significant credential leak risk. This implementation uses **OpenID Connect (OIDC)** identity federation:

1. **OIDC Provider**: Registered for `https://token.actions.githubusercontent.com`.
2. **Trust Policy Condition**: Restricts role assumption via `AssumeRoleWithWebIdentity` using two strict claims:
   - `token.actions.githubusercontent.com:aud == "sts.amazonaws.com"`
   - `token.actions.githubusercontent.com:sub LIKE "repo:ORGANIZATION/REPOSITORY:*"`
3. **Short-Lived Tokens**: AWS Security Token Service (STS) issues temporary credentials valid for 1 hour that expire automatically.

---

## 3. Zero-SSH Architecture via AWS Systems Manager

- **Port 22 is completely omitted** from all Security Groups.
- Developers and SREs access instances via **AWS SSM Session Manager**:
  ```bash
  aws ssm start-session --target i-0123456789abcdef0
  ```
- **Benefits**:
  - No public IP required on EC2 instances.
  - No bastion jump hosts required.
  - No private SSH key management or rotation overhead.
  - Every session and command is logged to AWS CloudWatch / CloudTrail for compliance auditing.

---

## 4. EC2 Metadata Service Protection (IMDSv2)

To prevent Server-Side Request Forgery (SSRF) vulnerabilities from extracting IAM instance profile credentials:
- `http_tokens = "required"`: Strictly enforces IMDSv2. Classic IMDSv1 (unauthenticated HTTP GET) is disabled.
- `http_put_response_hop_limit = 1`: Prevents token forwarding across network proxies or container bridges.

When the application queries instance metadata, it first acquires a session token via `PUT /latest/api/token`:
```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" "http://169.254.169.254/latest/meta-data/instance-id")
```

---

## 5. Secrets Management & Credential Isolation

- **Zero Plaintext Credentials in Git**:
  - Database master password is generated dynamically using Terraform `random_password`.
  - Secret value stored directly into **AWS Secrets Manager** container.
  - Terraform outputs mark the password as `sensitive = true`, preventing leakage in CLI logs or CI output.
- **Application Ingestion**:
  - EC2 bootstrap script queries AWS Secrets Manager over encrypted HTTPS using IAM role permissions.
  - The secret is written to `/opt/app/.env` with strict Linux permissions:
    ```bash
    chmod 600 /opt/app/.env
    chown appuser:appuser /opt/app/.env
    ```
  - The Node.js application process runs as unprivileged user `appuser` (not `root`).

---

## 6. S3 Bucket Hardening & Policy Enforcement

Both S3 buckets (`alb-logs` and `app-storage`) adhere to strict security baselines:

1. **Public Access Block**: All four settings (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`) are set to `true`.
2. **Object Ownership**: Configured to `BucketOwnerEnforced`. Disables legacy ACLs and enforces IAM ownership.
3. **Encryption at Rest**: Server-Side Encryption with Amazon S3 managed keys (`AES256`) enabled by default on all bucket objects.
4. **Encryption in Transit (TLS Only)**: Bucket policies enforce HTTPS transport by explicitly denying non-SSL requests:
   ```json
   {
     "Sid": "EnforceSecureTransport",
     "Effect": "Deny",
     "Principal": "*",
     "Action": "s3:*",
     "Resource": ["arn:aws:s3:::bucket-name", "arn:aws:s3:::bucket-name/*"],
     "Condition": {
       "Bool": { "aws:SecureTransport": "false" }
     }
   }
   ```
5. **ALB Log Delivery Permissions**: Scoped specifically to AWS Regional Elastic Load Balancing Service Principal (`data.aws_elb_service_account.main.arn`) and `delivery.logs.amazonaws.com`.

---

## 7. Network Isolation & Threat Surface Minimization

```
Zone             Internet Access    Direct Inbound Access    Components
-------------------------------------------------------------------------------
Public           Bidirectional      Port 80 (Redirect), 443  ALB, NAT Gateways
Private App      Outbound (via NAT) Port 8080 (From ALB-SG)  EC2 Auto Scaling Nodes
Private DB       NONE (Isolated)    Port 3306 (From EC2-SG)  RDS MySQL Database
```

- **Database Air-Gap**: The RDS MySQL subnets have **no route to the Internet Gateway** and **no route to the NAT Gateway**. Even if a zero-day exploit existed in MySQL, the database cannot establish outbound command-and-control communication with the internet.
- **Application Isolation**: The EC2 instances reside in private subnets with no public IPv4 addresses. Direct inbound connections from the internet are impossible.

---

## 8. Threat Matrix & Countermeasures

| Threat Vector | Potential Impact | Implemented Countermeasure |
|---|---|---|
| **SSRF to IMDS** | AWS credential exfiltration | Strictly enforced IMDSv2 (`http_tokens = required`, `hop_limit = 1`) |
| **Credential Leakage in Git** | Database compromise | Dynamic generation in Terraform, stored directly in AWS Secrets Manager |
| **Insecure Transport** | Eavesdropping / Man-in-the-Middle | Inbound HTTP 301 redirected to HTTPS; TLS 1.3/1.2 enforced; S3 SSL deny policy |
| **Lateral Movement** | Attacker compromises one tier and pivots | Strict Security Group chaining: ALB SG -> EC2 SG -> RDS SG |
| **Brute-Force SSH** | Host compromise | Inbound Port 22 closed; Zero SSH; AWS SSM Session Manager with MFA |
| **CI/CD Token Leakage** | Full AWS account takeover | GitHub OIDC temporary STS session assumption; Zero long-lived access keys |
| **DDoS on Backend Instances** | Resource exhaustion | Internet-facing ALB with Target Group connection draining and AWS Shield Standard |
| **S3 Data Leakage** | Public bucket exposure | S3 Block Public Access enabled; BucketOwnerEnforced; Bucket policy restrictions |
