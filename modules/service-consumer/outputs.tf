output "endpoint_id" {
  description = "Interface endpoint ID. The service owner accepts this ID."
  value       = aws_vpc_endpoint.shared_service.id
}

output "endpoint_dns_name" {
  description = "Regional DNS name generated for the endpoint."
  value       = aws_vpc_endpoint.shared_service.dns_entry[0].dns_name
}

output "endpoint_private_dns_enabled" {
  description = "Whether AWS-managed private DNS is enabled on the endpoint (false: this module uses its own private zone)."
  value       = aws_vpc_endpoint.shared_service.private_dns_enabled
}

output "service_url" {
  description = "URL callers in this VPC use."
  value       = "https://${var.service_hostname}${var.service_port == 443 ? "" : ":${var.service_port}"}"
}

output "client_security_group_id" {
  description = "Attach this security group to any workload that should be able to call the shared service."
  value       = aws_security_group.client.id
}

output "endpoint_security_group_id" {
  description = "Security group on the interface endpoint."
  value       = aws_security_group.endpoint.id
}

output "endpoint_ingress_source_security_group_id" {
  description = "The only source allowed into the endpoint."
  value       = aws_vpc_security_group_ingress_rule.endpoint_from_client.referenced_security_group_id
}

output "test_client_instance_id" {
  description = "Test client instance ID, or null."
  value       = one(aws_instance.test_client[*].id)
}

output "test_client_private_ip" {
  description = "Test client private IP, or null."
  value       = one(aws_instance.test_client[*].private_ip)
}
