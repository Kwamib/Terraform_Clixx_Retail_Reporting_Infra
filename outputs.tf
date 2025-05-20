output "vpc_id" {
  value = aws_vpc.clixx_vpc.id
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public_subnets : subnet.id]
}

output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private_subnets : subnet.id]
}

output "target_group_arn" {
  description = "The ARN of the CliXX Web Application Target Group"
  value       = aws_lb_target_group.clixx_web_tg.arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.clixx_asg.name
}

output "asg_instances" {
  description = "List of instance IDs in the Auto Scaling Group"
  value       = data.aws_instances.clixx_asg_instances.ids
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.clixx_lb.dns_name
}

# ==========================================
# Outputs for Debugging
# ==========================================

# These outputs help debug and verify configuration
output "debug_availability_zones" {
  description = "Available Availability Zones being used"
  value       = local.availability_zones
}

output "debug_account_info" {
  description = "AWS Account information"
  value = {
    account_id = local.account_id
    region     = var.aws_region
    caller_arn = data.aws_caller_identity.current.arn
  }
}

output "debug_subnet_configuration" {
  description = "Subnet configuration being used"
  value = {
    public_subnets  = local.public_subnet_cidrs
    private_subnets = local.private_subnet_cidrs
  }
  sensitive = false
}
output "efs_id" {
  value = aws_efs_file_system.clixx_efs.dns_name
}


# Database-related outputs
output "rds_endpoint" {
  description = "The connection endpoint for the RDS database"
  value       = aws_db_instance.clixx_db_from_snapshot.endpoint
}

output "rds_port" {
  description = "The port on which the RDS database accepts connections"
  value       = aws_db_instance.clixx_db_from_snapshot.port
}

output "rds_name" {
  description = "The name of the RDS database"
  value       = aws_db_instance.clixx_db_from_snapshot.identifier
}

output "ssm_db_endpoint_parameter" {
  description = "The SSM parameter name that contains the RDS endpoint"
  value       = aws_ssm_parameter.db_endpoint.name
}