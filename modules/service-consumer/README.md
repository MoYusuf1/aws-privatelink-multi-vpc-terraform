# service-consumer

One consumer team's side: an interface endpoint in its VPC, a private hosted zone so callers use a stable hostname, dedicated client and endpoint security groups, and an optional test client reached through EC2 Instance Connect Endpoint.

## Usage

See the root `main.tf` for how this module is called.

## Inputs

| Name | Description | Type | Required |
|---|---|---|---|
| `name` | Consumer name, used as a prefix (for example \"payments\"). | `string` | yes |
| `vpc_id` | Consumer VPC. | `string` | yes |
| `subnet_ids` | Private subnets for the interface endpoint, one per AZ. Must be in AZs the endpoint service supports. | `list(string)` | yes |
| `service_name` | Endpoint service name published by the provider (com.amazonaws.vpce.<region>.vpce-svc-...). | `string` | yes |
| `service_port` | TCP port of the shared service. | `number` | no |
| `service_hostname` | Private hostname callers use, for example app.shared.internal. Needs at least three labels. | `string` | yes |
| `create_test_client` | Create a small EC2 client plus an EC2 Instance Connect Endpoint for testing. | `bool` | no |
| `instance_type` | Instance type for the test client. | `string` | no |
| `ami_ssm_parameter` | Public SSM parameter holding the AMI ID for the test client. | `string` | no |

## Outputs

| Name | Description |
|---|---|
| `endpoint_id` | Interface endpoint ID. The service owner accepts this ID. |
| `endpoint_dns_name` | Regional DNS name generated for the endpoint. |
| `endpoint_private_dns_enabled` | Whether AWS-managed private DNS is enabled on the endpoint (false: this module uses its own private zone). |
| `service_url` | URL callers in this VPC use. |
| `client_security_group_id` | Attach this security group to any workload that should be able to call the shared service. |
| `endpoint_security_group_id` | Security group on the interface endpoint. |
| `endpoint_ingress_source_security_group_id` | The only source allowed into the endpoint. |
| `test_client_instance_id` | Test client instance ID, or null. |
| `test_client_private_ip` | Test client private IP, or null. |

## Resources

- `aws_security_group.client`
- `aws_security_group.endpoint`
- `aws_vpc_security_group_egress_rule.client_to_endpoint`
- `aws_vpc_security_group_ingress_rule.endpoint_from_client`
- `aws_vpc_endpoint.shared_service`
- `aws_route53_zone.shared_service`
- `aws_route53_record.shared_service`
- `aws_security_group.eice`
- `aws_vpc_security_group_egress_rule.eice_to_client`
- `aws_vpc_security_group_ingress_rule.client_from_eice`
- `aws_ec2_instance_connect_endpoint.this`
- `aws_instance.test_client`
