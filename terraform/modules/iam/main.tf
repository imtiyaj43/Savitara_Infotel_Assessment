# ==============================================================================
# IAM Role & Instance Profile for EC2 Auto Scaling Instances
# ==============================================================================

# Trust Policy: EC2 instances can assume this role
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project_name}-${var.environment}-ec2-role"
  description        = "IAM Role for EC2 instances running ${var.project_name} application"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-role"
    }
  )
}

# Attach AWS Systems Manager Core policy (Zero-SSH policy)
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom Least-Privilege Policy for EC2
data "aws_iam_policy_document" "ec2_app_policy" {
  # 1. Read access to DB credentials secret in AWS Secrets Manager
  statement {
    sid    = "AllowSecretsManagerRead"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [var.db_secret_arn]
  }

  # 2. Read and write access to Application Storage S3 bucket
  statement {
    sid    = "AllowAppStorageS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      var.app_storage_bucket_arn,
      "${var.app_storage_bucket_arn}/*"
    ]
  }

  # 3. CloudWatch Logs delivery
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/ec2/${var.project_name}-${var.environment}*"]
  }
}

resource "aws_iam_policy" "ec2_app_policy" {
  name        = "${var.project_name}-${var.environment}-ec2-policy"
  description = "Least-privilege policy for application EC2 instances"
  policy      = data.aws_iam_policy_document.ec2_app_policy.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ec2_app_policy" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_app_policy.arn
}

# EC2 Instance Profile attached to Launch Template
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = var.tags
}

# ==============================================================================
# GitHub Actions CI/CD OIDC IAM Role
# ==============================================================================

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# GitHub OIDC Provider URL
locals {
  github_oidc_url = "https://token.actions.githubusercontent.com"
  oidc_provider_arn = var.create_github_oidc_role ? (
    var.create_oidc_provider ? (
      length(aws_iam_openid_connect_provider.github) > 0 ? aws_iam_openid_connect_provider.github[0].arn : ""
      ) : (
      var.existing_oidc_provider_arn != "" ? var.existing_oidc_provider_arn : "arn:aws:iam://${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
    )
  ) : ""
}

# TLS Certificate thumbprint for GitHub OIDC
data "tls_certificate" "github" {
  count = var.create_github_oidc_role && var.create_oidc_provider ? 1 : 0
  url   = "${local.github_oidc_url}/.well-known/openid-configuration"
}

# Create OIDC provider if requested and not already existing in account
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_role && var.create_oidc_provider ? 1 : 0
  url             = local.github_oidc_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github[0].certificates[0].sha1_fingerprint]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-github-oidc-provider"
    }
  )
}

# IAM Role assumed by GitHub Actions via OIDC
data "aws_iam_policy_document" "github_oidc_assume" {
  count = var.create_github_oidc_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        var.github_repo == "*" ? "repo:*" : "repo:${var.github_repo}:*"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count              = var.create_github_oidc_role ? 1 : 0
  name               = "${var.project_name}-${var.environment}-github-actions-role"
  description        = "IAM Role assumed by GitHub Actions CI/CD via OpenID Connect (OIDC)"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume[0].json

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-github-actions-role"
    }
  )
}

# Attach PowerUserAccess or specific policy to GitHub Actions Role for Terraform IaC
resource "aws_iam_role_policy_attachment" "github_actions_poweruser" {
  count      = var.create_github_oidc_role ? 1 : 0
  role       = aws_iam_role.github_actions[0].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# Additional IAM policy for GitHub Actions to manage IAM roles during Terraform apply
resource "aws_iam_role_policy" "github_actions_iam_pass_role" {
  count = var.create_github_oidc_role ? 1 : 0
  name  = "TerraformIAMManagement"
  role  = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowIAMManagementForTerraform"
        Effect = "Allow"
        Action = [
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
        ]
        Resource = "*"
      }
    ]
  })
}
