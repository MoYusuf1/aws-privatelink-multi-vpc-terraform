# service-provider

Publishes one application as a PrivateLink endpoint service: internal NLB with Proxy Protocol v2 and cross-zone load balancing, an Auto Scaling group across AZs, approval-required endpoint service with an allow list, and a healthy-host alarm. The app tier has no egress.

## Usage

See the root `main.tf` for how this module is called.

## Inputs

| Name | Description | Type | Required |
|---|---|---|---|
| `name` | Prefix for resource names. | `string` | yes |
| `vpc_id` | VPC that hosts the service. | `string` | yes |
| `subnet_ids` | Private subnets for the NLB and app instances, one per AZ. These AZs are the only ones consumers can use. | `list(string)` | yes |
| `service_port` | TCP port the service listens on end to end. | `number` | no |
| `service_hostname` | Hostname consumers use for the service. Written into the instance TLS certificate. | `string` | yes |
| `consumer_cidrs` | Map of consumer name to VPC CIDR allowed through the NLB security group. | `map(string)` | yes |
| `allowed_principal_arns` | IAM principals (normally account roots) allowed to request a connection to the endpoint service. | `set(string)` | yes |
| `instance_type` | Instance type for the app tier. | `string` | no |
| `instance_count` | Number of app instances. Keep it at least the number of AZs so every AZ has a target. | `number` | no |
| `ami_ssm_parameter` | Public SSM parameter holding the AMI ID. | `string` | no |
| `deletion_protection` | Enable NLB deletion protection. | `bool` | no |
| `alarm_actions` | ARNs (for example an SNS topic) notified when the healthy host alarm changes state. | `list(string)` | no |

## Outputs

| Name | Description |
|---|---|
| `service_name` | Endpoint service name consumers connect to. Only available once the allowed principals exist, so consumers never race ahead of the allow list. |
| `service_id` | Endpoint service ID, used to accept connection requests. |
| `acceptance_required` | Whether every consumer connection needs explicit approval. |
| `proxy_protocol_v2` | Whether Proxy Protocol v2 is enabled on the target group. |
| `nlb_arn` | ARN of the internal NLB. |
| `nlb_subnet_ids` | Subnets the NLB spans. |
| `nlb_security_group_id` | Security group on the NLB. |
| `app_security_group_id` | Security group on the app instances. |
| `nlb_ingress_cidrs` | CIDRs allowed through the NLB security group. |
| `app_ingress_source_security_group_id` | The only source allowed into the app tier. |
| `target_group_arn` | ARN of the app target group. |
| `autoscaling_group_name` | Name of the app Auto Scaling group. |

## Resources

- `aws_security_group.nlb`
- `aws_security_group.app`
- `aws_vpc_security_group_ingress_rule.nlb_from_consumers`
- `aws_vpc_security_group_egress_rule.nlb_to_app`
- `aws_vpc_security_group_ingress_rule.app_from_nlb`
- `aws_launch_template.app`
- `aws_autoscaling_group.app`
- `aws_lb.this`
- `aws_lb_target_group.app`
- `aws_lb_listener.app`
- `aws_vpc_endpoint_service.this`
- `aws_vpc_endpoint_service_allowed_principal.consumers`
- `aws_cloudwatch_metric_alarm.healthy_hosts`
