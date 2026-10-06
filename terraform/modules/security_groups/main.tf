# ==============================================================================
# Security Group: Application Load Balancer (ALB)
# ==============================================================================
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer (HTTPS & HTTP redirect)"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-alb-sg"
      Role = "LoadBalancer"
    }
  )
}

# Ingress: HTTP (Port 80) for 301 redirection to HTTPS
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow inbound HTTP traffic for redirection to HTTPS"
  security_group_id = aws_security_group.alb.id
}

# Ingress: HTTPS (Port 443) for secure encrypted client traffic
resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow inbound HTTPS client traffic"
  security_group_id = aws_security_group.alb.id
}

# ==============================================================================
# Security Group: EC2 Auto Scaling Instances (Application Tier)
# ==============================================================================
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for EC2 instances in private subnets"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-ec2-sg"
      Role = "ApplicationCompute"
    }
  )
}

# ALB Egress to EC2 instances on App Port
resource "aws_security_group_rule" "alb_egress_to_ec2" {
  type                     = "egress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  description              = "Forward traffic from ALB to EC2 instances on application port"
  security_group_id        = aws_security_group.alb.id
}

# EC2 Ingress: ONLY from ALB Security Group on App Port
resource "aws_security_group_rule" "ec2_ingress_from_alb" {
  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow incoming application traffic strictly from ALB"
  security_group_id        = aws_security_group.ec2.id
}

# EC2 Egress: HTTPS to Internet (via NAT Gateway) for AWS APIs (Secrets Manager, SSM, S3)
resource "aws_security_group_rule" "ec2_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound HTTPS for AWS APIs, SSM, and package downloads"
  security_group_id = aws_security_group.ec2.id
}

# EC2 Egress: HTTP to Internet for OS package repositories
resource "aws_security_group_rule" "ec2_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound HTTP for software updates and package repositories"
  security_group_id = aws_security_group.ec2.id
}

# EC2 Egress: DNS queries (UDP 53) for Amazon Route 53 Resolver / domain resolution
resource "aws_security_group_rule" "ec2_egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound DNS queries over UDP"
  security_group_id = aws_security_group.ec2.id
}

# EC2 Egress: DNS queries (TCP 53) for large DNS responses
resource "aws_security_group_rule" "ec2_egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound DNS queries over TCP"
  security_group_id = aws_security_group.ec2.id
}

# EC2 Egress: NTP (UDP 123) for Amazon Time Sync Service / Chrony
resource "aws_security_group_rule" "ec2_egress_ntp" {
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound NTP for Amazon Time Sync Service"
  security_group_id = aws_security_group.ec2.id
}

# ==============================================================================
# Security Group: RDS MySQL (Database Tier)
# ==============================================================================
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Security group for RDS MySQL in private database subnets"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-sg"
      Role = "Database"
    }
  )
}

# EC2 Egress: MySQL (Port 3306) to RDS Security Group
resource "aws_security_group_rule" "ec2_egress_to_rds" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  description              = "Allow outbound MySQL connections from EC2 to RDS"
  security_group_id        = aws_security_group.ec2.id
}

# RDS Ingress: MySQL (Port 3306) ONLY from EC2 Security Group
resource "aws_security_group_rule" "rds_ingress_from_ec2" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2.id
  description              = "Allow inbound MySQL traffic strictly from application EC2 instances"
  security_group_id        = aws_security_group.rds.id
}
