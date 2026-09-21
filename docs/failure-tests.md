# Failure tests

A design only earns trust once it survives a failure you caused on purpose. Run these after `terraform apply` finishes and both test clients return a response. Each test lists what to do, what you should see, how to confirm it, and how to recover.

Keep a Payments session open in one terminal for the whole run:

```bash
# Printed with real IDs by: terraform output -raw try_it
aws ec2-instance-connect ssh --connection-type eice --instance-id <payments-client-id>

# Inside the client, call the service once per second
while true; do curl -sk --max-time 3 https://app.shared.internal | grep -E 'served_by|caller_vpce' || echo "FAILED $(date +%T)"; sleep 1; done
```

---

## Test 1: lose an application instance

**Why:** proves the service survives the loss of one Availability Zone's capacity without anyone touching the code.

**Do:**

```bash
ASG=$(terraform output -raw app_autoscaling_group_name)
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
  --query 'AutoScalingGroups[0].Instances[].[InstanceId,AvailabilityZone]' --output table
aws ec2 terminate-instances --instance-ids <one-of-the-ids>
```

**Expect:**

- The loop may show a few `FAILED` lines for connections that were open to that instance, then `served_by` shows only the surviving instance.
- The target group marks the instance unhealthy after about 30 seconds (3 checks, 10 seconds apart).
- The `-healthy-hosts-low` CloudWatch alarm goes to `ALARM`.
- Auto Scaling launches a replacement. Once it passes health checks, `served_by` alternates between two instances again and the alarm returns to `OK`.

**Confirm:** `terraform plan` shows no changes. Recovery happened inside the design, not through a code change.

---

## Test 2: revoke one consumer

**Why:** proves access is granted per service and per consumer, and that removing one consumer does not affect the other.

**Do:** in `main.tf`, comment out the `analytics` line in `aws_vpc_endpoint_connection_accepter.consumers`, then:

```bash
terraform apply
```

Removing the accepter rejects the connection (the provider calls `RejectVpcEndpointConnections`).

**Expect:**

- From the Analytics client, `curl -sk --max-time 5 https://app.shared.internal` now fails.
- The Payments loop keeps succeeding the whole time.
- In the console, the endpoint service shows the Analytics connection as `Rejected`.

**Recover:** uncomment the line. A rejected endpoint has to ask again, so recreate it and let the accepter approve the new request:

```bash
terraform apply -replace='module.analytics_consumer.aws_vpc_endpoint.shared_service'
```

That is also how a real team would be re-onboarded: a new request, a reviewed approval, and a record of both.

---

## Test 3: a manual change that health checks cannot see

**Why:** proves two things. A layer 4 health check can report healthy while every real request fails, and Terraform detects and reverses manual drift.

**Do:** simulate someone "fixing" something in the console by turning Proxy Protocol off:

```bash
TG=$(terraform output -raw app_target_group_arn)
aws elbv2 modify-target-group-attributes --target-group-arn "$TG" \
  --attributes Key=proxy_protocol_v2.enabled,Value=false
```

**Expect:**

- The Payments loop turns into `FAILED` lines. The app expects every connection to start with a Proxy Protocol header, finds a TLS handshake instead, and closes the connection.
- The target group still shows every target as healthy. A TCP health check only proves the port accepts a connection.

```bash
aws elbv2 describe-target-health --target-group-arn "$TG" \
  --query 'TargetHealthDescriptions[].TargetHealth.State'
```

**Diagnose, one layer at a time:**

1. DNS: `getent hosts app.shared.internal` still resolves to the endpoint's private IPs.
2. Network: flow logs in the Shared Services VPC still show accepted traffic to the NLB and the instances.
3. Load balancer: targets are healthy, so the fault is above the TCP layer.
4. Configuration: `terraform plan` shows exactly what changed.

```bash
terraform plan   # ~ proxy_protocol_v2 = false -> true
```

**Recover:** `terraform apply`. The loop recovers within a few seconds.

**Lesson:** a green health check proves a server is listening, not that it can serve a real request. In production, pair TCP checks with a synthetic request that exercises the real path.

---

## Test 4: an unsafe change never reaches AWS

**Why:** proves the guardrails in the code stop a bad change at plan time.

**Do:**

```bash
terraform plan -var='vpc_cidrs={shared="10.10.0.0/16",payments="10.0.0.0/8",analytics="10.30.0.0/16"}'
```

**Expect:** the plan fails on the `vpc_cidrs` validation. The NLB security group filters consumers by address range, so overlapping ranges would silently let one team pass as another. Terraform refuses before anything is created.
