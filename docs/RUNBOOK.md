# Operational Runbook & Troubleshooting Guide

## 1. Connecting to Private EC2 Instances (Zero-SSH via AWS SSM)

Because inbound SSH port 22 is disabled across all security groups, connect to instances using **AWS Systems Manager Session Manager**.

### Prerequisites
- AWS CLI configured with active credentials.
- AWS Session Manager Plugin installed ([Install Guide](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)).

### Connect to an ASG Instance
```bash
# 1. Identify running instances in the Auto Scaling Group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform -chdir=terraform output -raw autoscaling_group_name) \
  --query "AutoScalingGroups[0].Instances[*].InstanceId" \
  --output table

# 2. Start interactive SSM terminal session
aws ssm start-session --target <INSTANCE_ID>
```

---

## 2. Inspecting Application & Bootstrap Logs

Once connected to an instance via SSM:

```bash
# 1. Check systemd service status
sudo systemctl status savitara-app.service

# 2. Tail live application logs
sudo journalctl -u savitara-app.service -f

# 3. Inspect cloud-init bootstrap log
sudo tail -n 100 /var/log/cloud-init-output.log

# 4. Verify local application response
curl -i http://127.0.0.1:8080/health
curl -i http://127.0.0.1:8080/db-check
```

---

## 3. Simulating Auto Scaling Policy (CPU Stress Test)

To test the Target Tracking CPU policy (which scales out when Average CPU > 70%):

```bash
# Connect to an instance via SSM
aws ssm start-session --target <INSTANCE_ID>

# Install stress utility
sudo dnf install -y stress

# Run high CPU load across all vCPUs for 10 minutes
sudo stress --cpu 2 --timeout 600s
```

Observe the Auto Scaling Group in the AWS Console or via AWS CLI:
```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $(terraform -chdir=terraform output -raw autoscaling_group_name) \
  --max-items 5
```
The ASG will detect the CloudWatch high CPU alarm and scale out capacity from 2 to 3 or 4 instances.

---

## 4. Zero-Downtime Rolling Update (Instance Refresh)

To deploy an updated AMI or updated user data without downtime:

1. Update the Launch Template in Terraform.
2. Trigger an ASG Instance Refresh:
   ```bash
   aws autoscaling start-instance-refresh \
     --auto-scaling-group-name $(terraform -chdir=terraform output -raw autoscaling_group_name) \
     --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 180}'
   ```
3. Check progress:
   ```bash
   aws autoscaling describe-instance-refreshes \
     --auto-scaling-group-name $(terraform -chdir=terraform output -raw autoscaling_group_name)
   ```
   The ASG terminates and replaces instances one by one, waiting for each new instance to pass ALB `/health` checks before proceeding to the next.

---

## 5. Troubleshooting Scenarios & Resolution

### Issue 1: ALB Returns HTTP 502 Bad Gateway
- **Cause**: ALB cannot connect to the backend EC2 instances on port 8080, or the application process is crashed.
- **Diagnostic Steps**:
  1. Check ALB Target Group health:
     ```bash
     aws elbv2 describe-target-health --target-group-arn $(terraform -chdir=terraform output -raw target_group_arn)
     ```
  2. If targets show `unhealthy` with status `Target.FailedHealthCheck`:
     - Connect to instance via SSM.
     - Verify application is running: `systemctl status savitara-app`.
     - Check local response: `curl -I http://127.0.0.1:8080/health`.
  3. Verify `ec2-sg` permits inbound TCP 8080 from `alb-sg`.

### Issue 2: Application Returns Database Connection Error (503)
- **Cause**: EC2 instance cannot establish connection to RDS MySQL on port 3306, or bad credentials.
- **Diagnostic Steps**:
  1. Check RDS status:
     ```bash
     aws rds describe-db-instances --db-instance-identifier $(terraform -chdir=terraform output -raw rds_endpoint | cut -d: -f1)
     ```
  2. Test network connectivity from EC2 via SSM:
     ```bash
     nc -zv <RDS_HOST> 3306
     ```
  3. Verify `rds-sg` ingress rule allows port 3306 with source `ec2-sg`.
  4. Verify the secret in AWS Secrets Manager matches the RDS endpoint and credentials:
     ```bash
     aws secretsmanager get-secret-value --secret-id $(terraform -chdir=terraform output -raw secrets_manager_secret_name)
     ```

### Issue 3: Cloud-Init Bootstrap Hangs or Fails
- **Cause**: Instance cannot download packages or reach AWS APIs.
- **Diagnostic Steps**:
  1. Verify NAT Gateway is active and attached to a Public Subnet with an EIP.
  2. Verify the Private App Subnet route table has `0.0.0.0/0 -> nat-xxxx`.
  3. Verify `ec2-sg` has outbound rules for port 443 (HTTPS) and port 80 (HTTP).
  4. Inspect `/var/log/cloud-init-output.log` for package download errors.
