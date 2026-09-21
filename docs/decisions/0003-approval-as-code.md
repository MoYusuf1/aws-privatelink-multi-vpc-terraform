# 3. Manage consumer approval in Terraform

**Status:** Accepted

## Context

In the console version, consumers were approved by clicking Accept on the endpoint service. That left no reviewer and no record of who approved what, or why.

## Decision

Access takes two steps, both in code and both owned by Shared Services:

1. `aws_vpc_endpoint_service_allowed_principal` lists the accounts that may request a connection.
2. `aws_vpc_endpoint_connection_accepter` accepts each specific endpoint, keyed by consumer name.

The service name is only exported after the allow list exists, so no consumer can request a connection before its account is permitted.

## Consequences

- Positive: onboarding is a pull request that adds one line, with a reviewer. Revoking is removing that line, which rejects the connection without affecting any other consumer. The commit history is the audit trail.
- Negative: a rejected endpoint cannot simply be re-accepted. Restoring access means the consumer recreates its endpoint and the service owner approves the new request, which is the correct behavior for a revoked team but one more step.
- In a real multi-account setup the accepter would live in the Shared Services team's own stack and read consumer endpoint IDs from a request process, not from the consumer's module outputs.
