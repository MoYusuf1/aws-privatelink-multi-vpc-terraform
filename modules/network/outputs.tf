output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs, in the same order as var.az_ids."
  value       = [for az_id in var.az_ids : aws_subnet.private[az_id].id]
}

output "route_table_id" {
  description = "ID of the private route table."
  value       = aws_route_table.private.id
}

output "flow_log_group_name" {
  description = "CloudWatch Logs group receiving this VPC's flow logs."
  value       = aws_cloudwatch_log_group.flow_logs.name
}
