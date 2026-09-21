output "service_name" {
  description = "Endpoint service name consumers connect to. Only available once the allowed principals exist, so consumers never race ahead of the allow list."
  value       = aws_vpc_endpoint_service.this.service_name
  depends_on  = [aws_vpc_endpoint_service_allowed_principal.consumers]
}

output "service_id" {
  description = "Endpoint service ID, used to accept connection requests."
  value       = aws_vpc_endpoint_service.this.id
}

output "acceptance_required" {
  description = "Whether every consumer connection needs explicit approval."
  value       = aws_vpc_endpoint_service.this.acceptance_required
}

output "proxy_protocol_v2" {
  description = "Whether Proxy Protocol v2 is enabled on the target group."
  value       = aws_lb_target_group.app.proxy_protocol_v2
}

output "nlb_arn" {
  description = "ARN of the internal NLB."
  value       = aws_lb.this.arn
}

output "nlb_subnet_ids" {
  description = "Subnets the NLB spans."
  value       = aws_lb.this.subnets
}

output "nlb_security_group_id" {
  description = "Security group on the NLB."
  value       = aws_security_group.nlb.id
}

output "app_security_group_id" {
  description = "Security group on the app instances."
  value       = aws_security_group.app.id
}

output "nlb_ingress_cidrs" {
  description = "CIDRs allowed through the NLB security group."
  value       = sort([for rule in aws_vpc_security_group_ingress_rule.nlb_from_consumers : rule.cidr_ipv4])
}

output "app_ingress_source_security_group_id" {
  description = "The only source allowed into the app tier."
  value       = aws_vpc_security_group_ingress_rule.app_from_nlb.referenced_security_group_id
}

output "target_group_arn" {
  description = "ARN of the app target group."
  value       = aws_lb_target_group.app.arn
}

output "autoscaling_group_name" {
  description = "Name of the app Auto Scaling group."
  value       = aws_autoscaling_group.app.name
}
