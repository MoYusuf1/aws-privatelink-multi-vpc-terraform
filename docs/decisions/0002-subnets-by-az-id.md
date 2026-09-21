# 2. Place subnets by Availability Zone ID, not name

**Status:** Accepted

## Context

An interface endpoint can only be created in AZs where the endpoint service's NLB has a subnet. AZ names such as `us-east-1a` are mapped to physical zones independently in each AWS account, so the same name can mean different zones for the provider and a consumer.

## Decision

Every VPC is built from one shared list of AZ IDs (for example `use1-az1`, `use1-az2`). Subnets set `availability_zone_id`, never `availability_zone`. When no list is given, the root module picks the first two sorted zone IDs from the Shared Services account.

## Consequences

- Positive: the provider and every consumer land in the same physical zones in single-account and multi-account setups alike.
- Negative: AZ IDs are less familiar to read than names. Changing the list after deployment replaces subnets, so pin `az_ids` for anything long lived.
