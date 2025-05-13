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
