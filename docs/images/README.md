# Screenshots

Evidence that the design ran, captured during a real apply. Add these and the main README links to them.

| File | What it shows |
|---|---|
| `endpoint-service-accepted.png` | Endpoint service with both consumer connections Accepted |
| `caller-vpce-payments-analytics.png` | The same curl from Payments and Analytics returning different `caller_vpce` values |
| `failover-served-by.png` | Test 1: `served_by` switching to the surviving instance |
| `revoked-analytics.png` | Test 2: Analytics connection Rejected while Payments keeps working |
| `healthy-but-failing.png` | Test 3: every target healthy while requests fail |
| `plan-drift.png` | Test 3: `terraform plan` catching the manual change |
| `ci-green.png` | A pull request with all checks passing and the plan comment |
