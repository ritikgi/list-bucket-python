output "alb_dns_name" {
  description = "The DNS name of the ALB to access the application"
  value       = aws_lb.web_alb.dns_name
}