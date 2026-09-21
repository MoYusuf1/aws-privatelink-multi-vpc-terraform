# 5. Enforce NLB security group rules on PrivateLink traffic

**Status:** Accepted

## Context

Approval decides which endpoints may connect. Shared Services also wanted a network-level check on what reaches the NLB. For PrivateLink traffic, an NLB can either evaluate its inbound rules or skip them.

When enforcement is on, AWS evaluates the rules against the consumer client's private IP address.

## Decision

Keep enforcement on. The NLB security group allows only the Payments and Analytics VPC ranges, on the service port only. A validation on `vpc_cidrs` rejects any overlap between VPC ranges.

## Consequences

- Positive: a second gate after approval. Traffic from an unexpected range is dropped at the NLB even if an endpoint was approved by mistake.
- Negative: the rule depends on consumer ranges being unique. If a future consumer's range overlaps an existing one, this check cannot tell them apart. At that point, turn enforcement off and rely on approval, and record that as a new decision.
