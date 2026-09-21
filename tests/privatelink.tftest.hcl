# Mocked AWS providers: no credentials, no cost.
mock_provider "aws" {
  alias = "shared"

  # The provider validates ARN formats even under mocks.
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111111111111:role/mock-flow-logs" }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:111111111111:log-group:/vpc/mock/flow-logs" }
  }

  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0" }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:111111111111:loadbalancer/net/mock-nlb/0123456789abcdef"
      arn_suffix = "net/mock-nlb/0123456789abcdef"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:111111111111:targetgroup/app-mock/0123456789abcdef"
      arn_suffix = "targetgroup/app-mock/0123456789abcdef"
    }
  }

  mock_resource "aws_vpc_endpoint_service" {
    defaults = {
      id           = "vpce-svc-0123456789abcdef0"
      service_name = "com.amazonaws.vpce.us-east-1.vpce-svc-0123456789abcdef0"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names    = ["us-east-1a", "us-east-1b", "us-east-1c"]
      zone_ids = ["use1-az1", "use1-az2", "use1-az4"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
}

mock_provider "aws" {
  alias = "payments"

  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111111111111:role/mock-flow-logs" }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:111111111111:log-group:/vpc/mock/flow-logs" }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "222222222222" }
  }

  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }

  mock_resource "aws_vpc_endpoint" {
    defaults = {
      dns_entry = [{
        dns_name       = "vpce-0payments-abcd.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com"
        hosted_zone_id = "Z7HUB22UULQXV"
      }]
    }
  }
}

mock_provider "aws" {
  alias = "analytics"

  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111111111111:role/mock-flow-logs" }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:111111111111:log-group:/vpc/mock/flow-logs" }
  }

  mock_data "aws_caller_identity" {
    defaults = { account_id = "333333333333" }
  }

  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }

  mock_resource "aws_vpc_endpoint" {
    defaults = {
      dns_entry = [{
        dns_name       = "vpce-0analytics-abcd.vpce-svc-0123456789abcdef0.us-east-1.vpce.amazonaws.com"
        hosted_zone_id = "Z7HUB22UULQXV"
      }]
    }
  }
}

run "design_holds_with_defaults" {
  command = apply

  assert {
    condition     = module.shared_service.acceptance_required
    error_message = "The endpoint service must require approval for every consumer."
  }

  assert {
    condition     = module.shared_service.proxy_protocol_v2
    error_message = "Proxy Protocol v2 must be on so the app can identify callers."
  }

  assert {
    condition     = output.az_ids == tolist(["use1-az1", "use1-az2"])
    error_message = "Expected the first two AZ IDs when none are pinned."
  }

  assert {
    condition     = length(module.shared_services_network.private_subnet_ids) == 2
    error_message = "Shared Services needs one private subnet in each of two AZs."
  }

  assert {
    condition     = module.shared_service.nlb_subnet_ids == toset(module.shared_services_network.private_subnet_ids)
    error_message = "The NLB must span every Shared Services private subnet."
  }

  assert {
    condition     = module.shared_service.nlb_ingress_cidrs == tolist(["10.20.0.0/16", "10.30.0.0/16"])
    error_message = "Only the Payments and Analytics VPCs may reach the NLB. Nothing broader, never 0.0.0.0/0."
  }

  assert {
    condition     = module.shared_service.app_ingress_source_security_group_id == module.shared_service.nlb_security_group_id
    error_message = "App instances must accept traffic only from the NLB security group."
  }

  assert {
    condition     = module.payments_consumer.endpoint_ingress_source_security_group_id == module.payments_consumer.client_security_group_id
    error_message = "The Payments endpoint must accept traffic only from the Payments client security group."
  }

  assert {
    condition     = module.analytics_consumer.endpoint_ingress_source_security_group_id == module.analytics_consumer.client_security_group_id
    error_message = "The Analytics endpoint must accept traffic only from the Analytics client security group."
  }

  assert {
    condition     = toset(keys(aws_vpc_endpoint_connection_accepter.consumers)) == toset(["payments", "analytics"])
    error_message = "Each consumer needs exactly one explicit approval."
  }

  assert {
    condition     = module.payments_consumer.service_url == "https://app.shared.internal"
    error_message = "Consumers should call the stable private hostname, not the generated endpoint DNS name."
  }

  assert {
    condition     = !module.payments_consumer.endpoint_private_dns_enabled && !module.analytics_consumer.endpoint_private_dns_enabled
    error_message = "Private DNS comes from each consumer's private hosted zone, not the endpoint service."
  }
}

run "overlapping_cidrs_are_rejected" {
  command = plan

  variables {
    vpc_cidrs = {
      shared    = "10.10.0.0/16"
      payments  = "10.0.0.0/8"
      analytics = "10.30.0.0/16"
    }
  }

  expect_failures = [var.vpc_cidrs]
}

run "pinned_az_ids_are_used" {
  command = plan

  variables {
    az_ids = ["use1-az4", "use1-az2"]
  }

  assert {
    condition     = output.az_ids == tolist(["use1-az4", "use1-az2"])
    error_message = "Pinned AZ IDs must be used as given."
  }
}

run "test_clients_are_optional" {
  command = apply

  variables {
    create_test_clients = false
  }

  assert {
    condition     = module.payments_consumer.test_client_instance_id == null && module.analytics_consumer.test_client_instance_id == null
    error_message = "No test clients should exist when create_test_clients is false."
  }
}
