output "az_ids" {
  description = "AZ IDs every VPC, the NLB and both endpoints use."
  value       = local.az_ids
}

output "endpoint_service_name" {
  description = "Name consumers use to request a connection."
  value       = module.shared_service.service_name
}

output "endpoint_service_acceptance_required" {
  description = "Whether each consumer needs explicit approval."
  value       = module.shared_service.acceptance_required
}

output "accepted_connections" {
  description = "Endpoint connection state per consumer."
  value       = { for name, conn in aws_vpc_endpoint_connection_accepter.consumers : name => conn.vpc_endpoint_state }
}

output "consumers" {
  description = "What each consumer team needs to call the shared service."
  value = {
    payments = {
      endpoint_id              = module.payments_consumer.endpoint_id
      service_url              = module.payments_consumer.service_url
      client_security_group_id = module.payments_consumer.client_security_group_id
      test_client_instance_id  = module.payments_consumer.test_client_instance_id
      test_client_private_ip   = module.payments_consumer.test_client_private_ip
    }
    analytics = {
      endpoint_id              = module.analytics_consumer.endpoint_id
      service_url              = module.analytics_consumer.service_url
      client_security_group_id = module.analytics_consumer.client_security_group_id
      test_client_instance_id  = module.analytics_consumer.test_client_instance_id
      test_client_private_ip   = module.analytics_consumer.test_client_private_ip
    }
  }
}

output "app_autoscaling_group_name" {
  description = "Auto Scaling group running the shared application."
  value       = module.shared_service.autoscaling_group_name
}

output "app_target_group_arn" {
  description = "Target group behind the shared service NLB."
  value       = module.shared_service.target_group_arn
}

output "flow_log_groups" {
  description = "CloudWatch Logs groups with each VPC's flow logs."
  value = {
    shared_services = module.shared_services_network.flow_log_group_name
    payments        = module.payments_network.flow_log_group_name
    analytics       = module.analytics_network.flow_log_group_name
  }
}

output "try_it" {
  description = "Commands to verify the design once the app instances pass health checks."
  value = var.create_test_clients ? join("\n", [
    "# 1. From Payments, call the shared service by its private name:",
    "aws ec2-instance-connect ssh --region ${var.region} --connection-type eice --instance-id ${coalesce(module.payments_consumer.test_client_instance_id, "none")}",
    "curl -sk ${module.payments_consumer.service_url}   # caller_vpce should equal ${module.payments_consumer.endpoint_id}",
    "",
    "# 2. Still on the Payments client, try to reach the Analytics client directly. It should time out:",
    "curl -s --connect-timeout 5 http://${coalesce(module.analytics_consumer.test_client_private_ip, "none")} || echo 'unreachable, as designed'",
    "",
    "# 3. Repeat step 1 from Analytics and confirm caller_vpce changes to ${module.analytics_consumer.endpoint_id}",
    "aws ec2-instance-connect ssh --region ${var.region} --connection-type eice --instance-id ${coalesce(module.analytics_consumer.test_client_instance_id, "none")}",
  ]) : "Set create_test_clients = true to get test clients."
}
