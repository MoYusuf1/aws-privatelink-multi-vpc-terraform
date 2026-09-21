# 4. Identify callers with Proxy Protocol v2, and give the app no outbound access

**Status:** Accepted

## Context

Behind PrivateLink, every connection reaches the application from the NLB's own addresses, so the app cannot tell Payments from Analytics. Per-consumer logging, rate limiting, or chargeback all need that identity.

The first draft of the app installed nginx at boot. Package installs need a path out of the VPC, which meant either a NAT gateway or an S3 gateway endpoint for the Amazon Linux repos, plus an egress rule to maintain.

## Decision

- Enable Proxy Protocol v2 on the target group. For PrivateLink traffic, AWS adds TLV type `0xEA` carrying the caller's VPC endpoint ID.
- Replace nginx with a small Python server (`modules/service-provider/app/server.py`) that uses only the standard library. It parses the Proxy Protocol header, then performs the TLS handshake, then logs one JSON line per request with the caller's endpoint ID.
- Because nothing is installed at boot, the app security group has no egress rules at all.

## Consequences

- Positive: the app knows which consumer called. The app tier cannot initiate any connection, and there is no NAT gateway to pay for or secure.
- Negative: Proxy Protocol is all or nothing. An app that does not expect the header cannot read any request, and TCP health checks keep reporting targets as healthy while that happens (see Test 3 in `docs/failure-tests.md`). Enabling the header and updating the app must ship together.
- Negative: request logs stay on the instance until a CloudWatch Logs interface endpoint is added.
