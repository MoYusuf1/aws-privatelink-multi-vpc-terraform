# 1. Share the service over PrivateLink, not VPC peering or a public endpoint

**Status:** Accepted

## Context

Payments and Analytics each need one internal application owned by Shared Services. Payments handles transactions, so every network path into or out of it widens audit scope. The two consumers must never reach each other.

## Options considered

- **Public endpoint.** Works immediately, but turns a network boundary into an authentication problem and exposes the service to the internet.
- **VPC peering.** Connects whole networks, not one service. Once peered, security groups are the only boundary. Needs non-overlapping CIDRs and grows as n(n-1)/2 connections (ten VPCs means forty-five).
- **Transit Gateway.** Scales better than peering but still routes networks, and adds hourly and per-GB cost for a single service.
- **PrivateLink.** Publishes one service behind an NLB. Consumers get an endpoint in their own VPC. No routes are created in either direction.

## Decision

Use PrivateLink with approval required on the endpoint service.

## Consequences

- Positive: no route between any VPCs. The service owner approves each consumer individually. A new consumer is one approval and no route table changes.
- Negative: interface endpoints bill hourly per AZ plus data processed, while peering has no hourly charge. Only an NLB can front the service, so layer 7 routing sits behind it. Traffic is one way, so the service cannot call consumers back over the same path.
