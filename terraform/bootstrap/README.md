# Terraform Backend Bootstrap (S3 + DynamoDB)

This bootstrap module sets up the remote state storage and locking infrastructure for Terraform in AWS:
- **S3 Bucket**: Versioned, encrypted (AES-256), TLS-enforced, and blocks all public access.
- **DynamoDB Table**: Pay-per-request pricing with `LockID` primary key for state locking.

## Quick Provisioning

```bash
cd terraform/bootstrap
terraform init
terraform apply -auto-approve
```

The output will display the exact `backend "s3"` block to configure in `terraform/backend.tf`.
