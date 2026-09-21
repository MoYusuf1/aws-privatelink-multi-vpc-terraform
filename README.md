# Private Multi-VPC Service Sharing with AWS PrivateLink and Terraform

[![terraform](https://github.com/MoYusuf1/aws-privatelink-multi-vpc-terraform/actions/workflows/terraform.yml/badge.svg)](https://github.com/MoYusuf1/aws-privatelink-multi-vpc-terraform/actions/workflows/terraform.yml)
![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.10-7B42BC)
![AWS provider](https://img.shields.io/badge/aws%20provider-6.x-FF9900)
![License](https://img.shields.io/badge/license-MIT-blue)

**The safest way to let two teams share a service is to never connect their networks.**

Three isolated VPCs for a fintech scenario. Payments and Analytics both consume one internal application owned by Shared Services. They reach it privately through AWS PrivateLink with no VPC peering, no transit gateway, no internet gateway, and no public IP anywhere, and neither consumer can reach the other.

I first built this in the console ([article](https://www.linkedin.com/pulse/how-i-built-private-multi-vpc-architecture-aws-mohamed-yusuf-xjnoc/)). This repo rebuilds it in Terraform, adds the production improvements that article listed, and includes failure tests that break it on purpose to prove the controls hold ([article](#) coming soon).

## What this project demonstrates

| Skill | Where to look |
|---|---|
| Reusable Terraform modules | [`modules/`](modules), one network module called three times |
| Multi-account design | [`providers.tf`](providers.tf), one provider per team with optional `assume_role`, subnets placed by AZ ID ([ADR 2](docs/decisions/0002-subnets-by-az-id.md)) |
| Access governance as code | Consumer approval is a pull request ([ADR 3](docs/decisions/0003-approval-as-code.md)) |
| Least-privilege networking | A named security group per workload, an app tier with zero egress, NLB rules on PrivateLink traffic ([ADR 5](docs/decisions/0005-nlb-security-group-enforcement.md)) |
| Infrastructure testing | [`tests/`](tests), mocked `terraform test` with no AWS credentials |
| CI/CD and security scanning | [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml): fmt, validate, test, tflint, Checkov, and a read-only plan through GitHub OIDC |
| State management | [`bootstrap/`](bootstrap), S3 remote state with native lock files |
| Observability | VPC flow logs on every VPC, a healthy-host alarm, per-request JSON logs with the caller's endpoint ID |
| Operational readiness | [Runbook](docs/runbook.md) and [failure tests](docs/failure-tests.md) |
| Cost awareness | [Cost](#cost), about $0.11 an hour, one-command teardown |

## Architecture

```mermaid
flowchart LR
  subgraph PAY["Payments VPC 10.20.0.0/16"]
    PC[Client] -->|443| PE[Interface endpoint<br/>2 AZs]
    PZ[(Private zone<br/>app.shared.internal)] -.-> PE
  end

  subgraph ANA["Analytics VPC 10.30.0.0/16"]
    AC[Client] -->|443| AE[Interface endpoint<br/>2 AZs]
    AZ[(Private zone<br/>app.shared.internal)] -.-> AE
  end

  subgraph SS["Shared Services VPC 10.10.0.0/16"]
    ES[Endpoint service<br/>approval required] --> NLB[Internal NLB<br/>cross-zone, Proxy Protocol v2]
    NLB -->|TLS 443| ASG[App instances<br/>ASG across 2 AZs<br/>no egress at all]
  end

  PE ==>|PrivateLink| ES
  AE ==>|PrivateLink| ES
  PAY x--x|no route| ANA
```

A request from Payments resolves `app.shared.internal` to the endpoint in its own VPC, crosses the AWS network to the endpoint service, and reaches the application through the internal NLB. The NLB adds a Proxy Protocol v2 header carrying the caller's endpoint ID, so the application knows which team called. Analytics takes the same path through its own endpoint. Nothing touches the public internet, and nothing creates a route between VPCs.

## Example output

```
$ curl -sk https://app.shared.internal        # from the Payments client
shared-services app
served_by=i-0abc... (use1-az1)
caller_vpce=vpce-0payments...
```

Run the same request from Analytics and `caller_vpce` changes.

## What changed from the console version

| Console lab | This repo | Why |
|---|---|---|
| One EC2 instance | Auto Scaling group across two AZs with rolling instance refresh | Losing one AZ no longer takes the service down |
| HTTP | TLS end to end, terminated on the instances behind a TCP passthrough NLB | Encryption in transit without adding a layer 7 hop |
| The app could not tell callers apart | Proxy Protocol v2, and the app logs the caller's endpoint ID | Per-team logging, rate limits, or chargeback become possible |
| Generated endpoint DNS names | A private hosted zone per consumer with `app.shared.internal` | Callers keep one stable hostname |
| Broad security group rules | One group per workload, one port, NLB admits only consumer ranges, app admits only the NLB, default groups emptied | Every rule has one purpose a reviewer can read |
| No logs | Flow logs on all three VPCs and a healthy-host alarm | A record of what connected and when |
| Separated by VPC | One provider per team, ready for separate accounts | Accounts are the strongest boundary AWS offers |
| Approval clicked in the console | Approval declared in code | Every approval has a reviewer and a commit |

## Design decisions

Each decision is written up with the options considered and the tradeoffs accepted.

1. [PrivateLink over peering or a public endpoint](docs/decisions/0001-privatelink-over-peering.md)
2. [Subnets placed by AZ ID, not name](docs/decisions/0002-subnets-by-az-id.md)
3. [Consumer approval managed in Terraform](docs/decisions/0003-approval-as-code.md)
4. [Proxy Protocol v2 and an app tier with zero egress](docs/decisions/0004-proxy-protocol-and-zero-egress-app.md)
5. [NLB security group rules enforced on PrivateLink traffic](docs/decisions/0005-nlb-security-group-enforcement.md)

## Failure tests

A design only earns trust once it survives a failure you caused on purpose. [`docs/failure-tests.md`](docs/failure-tests.md) walks through each one.

| Test | What it proves |
|---|---|
| Terminate an app instance | The service keeps answering from the other AZ and Auto Scaling recovers with no code change |
| Revoke Analytics | Removing one approval cuts off one consumer and leaves the other untouched |
| Turn Proxy Protocol off by hand | TCP health checks stay green while every request fails, and `terraform plan` catches the drift |
| Plan with overlapping CIDRs | Validation stops an unsafe change before anything reaches AWS |

## Run it

Requirements: Terraform 1.10 or newer and AWS credentials for one account (or three roles, see [`terraform.tfvars.example`](terraform.tfvars.example)).

```bash
# 1. Remote state, once
terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply
terraform -chdir=bootstrap output -raw backend_hcl > backend.hcl

# 2. The lab
make init
make apply

# 3. Verification commands with real IDs filled in
make output
```

Tear down with `make destroy`. Destroy `bootstrap/` last, if at all.

## Tests and CI

`make test` runs `terraform test` against mocked AWS providers. It needs no credentials and costs nothing. The tests check that approval is required, Proxy Protocol v2 is on, the NLB spans two AZs, the NLB admits only consumer ranges, the app admits only the NLB, each endpoint admits only its own team's clients, both consumers are explicitly accepted, overlapping ranges are rejected, and test clients are optional.

Every pull request runs `fmt`, `validate`, `test`, `tflint`, and Checkov. With the repository variables `AWS_PLAN_ROLE_ARN` and `TF_STATE_BUCKET` set from the bootstrap stack, it also runs a read-only plan through GitHub OIDC and posts it on the pull request. CI never applies.

Checkov findings that do not fit a lab, such as customer managed KMS keys or a year of log retention, are skipped inline with a written reason next to the resource, so each tradeoff is visible where it was made.

## Cost

Approximate us-east-1 on-demand prices at the time of writing. Check the AWS pricing pages before relying on them.

| Resource | Approx. per hour |
|---|---|
| 2 interface endpoints across 2 AZs | $0.040 |
| Network Load Balancer, idle | $0.023 |
| 4 t3.micro instances (2 app, 2 test clients) | $0.042 |
| EBS, flow logs, alarm | under $0.01 |
| **Total** | **about $0.11 an hour, or $2.60 a day** |

EC2 Instance Connect Endpoints are free. Private hosted zones are $0.50 a month each, and AWS does not charge for a zone deleted within 12 hours of creation. Peering would have no hourly charge. The trade is a small recurring fee in exchange for never creating reachability that has to be policed.

## Repo layout

```
.
├── main.tf                      # 3 networks, the shared service, 2 consumers, approvals
├── providers.tf                 # one provider per team, optional assume_role
├── variables.tf / outputs.tf
├── modules/
│   ├── network/                 # isolated VPC, subnets by AZ ID, flow logs, default SG locked
│   ├── service-provider/        # NLB, ASG, endpoint service, allow list, alarm
│   │   └── app/server.py        # stdlib HTTPS app that reads Proxy Protocol v2
│   └── service-consumer/        # interface endpoint, private DNS, optional test client
├── bootstrap/                   # state bucket and GitHub OIDC plan role
├── tests/                       # mocked terraform test
├── docs/
│   ├── decisions/               # architecture decision records
│   ├── failure-tests.md
│   └── runbook.md
├── Makefile
└── .github/workflows/terraform.yml
```

## What I would improve next

- Ship the app's JSON request logs to CloudWatch through a CloudWatch Logs interface endpoint, keeping the no-internet design.
- Issue the service certificate from ACM Private CA so clients verify it instead of trusting it.
- Deploy across three real accounts and add a second Region with the same modules.
- Add a synthetic check that sends a real request through each endpoint, since a TCP health check cannot see application failures (Test 3).
