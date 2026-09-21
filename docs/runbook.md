# Runbook

Day-two operations for the shared service. Every change goes through a pull request so there is a reviewer and a record.

## Onboard a new consumer team

1. Add a provider alias for the team in `providers.tf` (with an `assume_role` if it has its own account).
2. Add a non-overlapping CIDR for the team to `vpc_cidrs` in `variables.tf`, and to `consumer_cidrs` in the `shared_service` module call.
3. Add a `network` module block and a `service-consumer` module block for the team in `main.tf`.
4. Add the team's account to `allowed_principal_arns` through `local.consumer_account_ids`.
5. Add one line to `aws_vpc_endpoint_connection_accepter.consumers`. This line is the approval.
6. Open a pull request. CI runs tests and posts the plan. Review it, merge, then `terraform apply`.
7. Give the team the `client_security_group_id` output and the service URL. Any workload with that security group can call the service.

## Revoke a consumer

1. Remove the team's line from `aws_vpc_endpoint_connection_accepter.consumers`.
2. Pull request, review, apply. The connection is rejected. Other consumers are not affected.
3. To fully offboard, also remove the team from `allowed_principal_arns` and `consumer_cidrs`, then remove its modules.

## Roll out a new app version or instance type

1. Change `modules/service-provider/app/server.py`, the user data template, or `app_instance_type`.
2. Apply. The launch template gets a new version and the Auto Scaling group starts an instance refresh, keeping at least 50 percent of instances healthy throughout.
3. Watch progress: `aws autoscaling describe-instance-refreshes --auto-scaling-group-name "$(terraform output -raw app_autoscaling_group_name)"`.

## Alarm: healthy hosts low

The `<prefix>-shared-healthy-hosts-low` alarm fires when fewer healthy targets than `app_instance_count` sit behind the NLB for 3 minutes.

1. Check target health: `aws elbv2 describe-target-health --target-group-arn "$(terraform output -raw app_target_group_arn)"`.
2. Check Auto Scaling activity for failed launches: `aws autoscaling describe-scaling-activities --auto-scaling-group-name "$(terraform output -raw app_autoscaling_group_name)" --max-items 5`.
3. If instances launch but stay unhealthy, read the boot log: `aws ec2 get-console-output --instance-id <id> --latest`. Look for the `shared-app` service failing to start.
4. If targets are healthy but consumers report failures, the fault is above TCP. Check for drift with `terraform plan` (see Test 3 in `docs/failure-tests.md`).

## A consumer reports the service is unreachable

Work through the path one layer at a time, from the consumer side:

1. DNS: `getent hosts app.shared.internal` from the consumer workload should return private IPs in its own VPC.
2. Security group: the workload must carry the consumer's `client_security_group_id`.
3. Endpoint state: `aws ec2 describe-vpc-endpoints --vpc-endpoint-ids <id> --query 'VpcEndpoints[0].State'` should be `available`, not `pendingAcceptance` or `rejected`.
4. NLB rule: the consumer's VPC range must be in the NLB security group (`consumer_cidrs`).
5. Targets: healthy targets in the target group.
6. Drift: `terraform plan` should show no changes.

## Tear down

`terraform destroy`, then optionally `terraform -chdir=bootstrap destroy`. The state bucket has versioning on, so empty it first if you destroy the bootstrap stack.
