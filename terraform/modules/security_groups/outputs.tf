output "alb_security_group_id" {
  description = "Security Group ID of the Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "Security Group ID of the EC2 Auto Scaling instances"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "Security Group ID of the RDS MySQL database"
  value       = aws_security_group.rds.id
}
