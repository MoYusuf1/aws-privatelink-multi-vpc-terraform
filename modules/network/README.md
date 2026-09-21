# network

An isolated VPC with private subnets placed by AZ ID, a local-only route table, VPC flow logs, and a default security group stripped of all rules. No internet gateway, NAT, or peering.

## Usage

See the root `main.tf` for how this module is called.

## Inputs

| Name | Description | Type | Required |
|---|---|---|---|
| `name` | Name used for the VPC and as a prefix for its resources. | `string` | yes |
| `cidr_block` | IPv4 CIDR for the VPC. Subnets are carved as /24s from it. | `string` | yes |
| `az_ids` | Availability Zone IDs (for example [\"use1-az1\", \"use1-az2\"]). One private subnet is created in each. | `list(string)` | yes |
| `flow_log_retention_days` | How long to keep VPC flow logs in CloudWatch Logs. | `number` | no |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC. |
| `cidr_block` | CIDR block of the VPC. |
| `private_subnet_ids` | Private subnet IDs, in the same order as var.az_ids. |
| `route_table_id` | ID of the private route table. |
| `flow_log_group_name` | CloudWatch Logs group receiving this VPC's flow logs. |

## Resources

- `aws_vpc.this`
- `aws_default_security_group.this`
- `aws_subnet.private`
- `aws_route_table.private`
- `aws_route_table_association.private`
- `aws_cloudwatch_log_group.flow_logs`
- `aws_iam_role.flow_logs`
- `aws_iam_role_policy.flow_logs`
- `aws_flow_log.this`
