output "vpc_id" {
  value = aws_vpc.clixx_vpc.id
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public_subnets: subnet.id]
}

output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private_subnets: subnet.id]
}

output "target_group_arn" {
  description = "The ARN of the CliXX Web Application Target Group"
  value       = aws_lb_target_group.clixx_web_tg.arn
}