output "lb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = aws_lb.main.dns_name
}

output "lb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer (to be used in Route 53 Alias records)."
  value       = aws_lb.main.zone_id
}

output "lb_arn" {
  description = "The ARN of the load balancer."
  value       = aws_lb.main.arn
}

output "lb_arn_suffix" {
  description = "The ARN suffix of the load balancer."
  value       = aws_lb.main.arn_suffix
}

# output "lb_security_group_id" {
#   description = "The ID of the security group attached to the load balancer."
#   value       = aws_security_group.lb.id
# }

output "http_listener_arn" {
  description = "The ARN of the HTTP listener (if created)."
  value       = try(aws_lb_listener.http[0].arn, null)
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener (if created)."
  value       = try(aws_lb_listener.https[0].arn, null)
}

output "default_target_group_arn" {
  description = "The ARN of the default target group (if created)."
  value       = try(aws_lb_target_group.default[0].arn, null)
}

output "default_target_group_name" {
  description = "The name of the default target group (if created)."
  value       = try(aws_lb_target_group.default[0].name, null)
}