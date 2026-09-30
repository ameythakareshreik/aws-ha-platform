output "alb_dns_name" {
  description = "The public URL of your Load Balancer"
  value       = "http://${aws_lb.web.dns_name}"
}

output "rds_endpoint" {
  description = "Multi-AZ RDS Endpoint DNS"
  value       = aws_db_instance.main.endpoint
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}