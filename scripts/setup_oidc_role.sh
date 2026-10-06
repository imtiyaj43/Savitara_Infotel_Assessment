#!/bin/bash
# Helper script to set up GitHub Actions OIDC Role via AWS CLI if desired outside Terraform
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: ./setup_oidc_role.sh <GITHUB_ORG_OR_USER> <GITHUB_REPO> [AWS_REGION]"
  echo "Example: ./setup_oidc_role.sh myorg savitara-infotel-aws us-east-1"
  exit 1
fi

GITHUB_OWNER="$1"
GITHUB_REPO="$2"
AWS_REGION="${3:-us-east-1}"
ROLE_NAME="github-actions-terraform-${GITHUB_REPO}"

echo "Configuring GitHub Actions OIDC Provider and IAM Role for: ${GITHUB_OWNER}/${GITHUB_REPO}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1. Create OIDC Provider if not exists
OIDC_PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN" 2>/dev/null; then
  echo "Creating OpenID Connect Provider for GitHub Actions..."
  aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
else
  echo "GitHub OIDC Provider already exists."
fi

# 2. Create Assume Role Trust Policy
TRUST_POLICY=$(cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_OWNER}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
)

# 3. Create or update IAM Role
if aws iam get-role --role-name "${ROLE_NAME}" 2>/dev/null; then
  echo "Updating assume role policy for ${ROLE_NAME}..."
  aws iam update-assume-role-policy --role-name "${ROLE_NAME}" --policy-document "${TRUST_POLICY}"
else
  echo "Creating IAM Role ${ROLE_NAME}..."
  aws iam create-role --role-name "${ROLE_NAME}" --assume-role-policy-document "${TRUST_POLICY}" --description "GitHub Actions CI/CD role for ${GITHUB_REPO}"
fi

# 4. Attach PowerUserAccess policy
aws iam attach-role-policy --role-name "${ROLE_NAME}" --policy-arn "arn:aws:iam::aws:policy/PowerUserAccess"

# 5. Attach IAM policy allowing Terraform to manage EC2 roles and instance profiles
echo "Attaching Terraform IAM management inline policy to ${ROLE_NAME}..."
IAM_POLICY=$(cat << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowIAMManagementForTerraform",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:GetPolicy",
        "iam:GetPolicyVersion",
        "iam:ListEntitiesForPolicy",
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:TagPolicy"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "TerraformIAMManagement" \
  --policy-document "${IAM_POLICY}"

ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "=========================================================="
echo "Successfully configured GitHub Actions OIDC Role!"
echo "Role ARN: ${ROLE_ARN}"
echo ""
echo "Add this to your GitHub Repository Secrets:"
echo "Secret Name: AWS_ROLE_ARN"
echo "Secret Value: ${ROLE_ARN}"
echo "=========================================================="
