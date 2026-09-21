data "aws_availability_zones" "shared" {
  #checkov:skip=CKV_AWS_394:Only used when var.az_ids is empty. Sorted AZ IDs keep the pick stable; pin var.az_ids for anything long lived.
  provider = aws.shared
  state    = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "payments" {
  provider = aws.payments
}

data "aws_caller_identity" "analytics" {
  provider = aws.analytics
}

data "aws_partition" "current" {
  provider = aws.shared
}

locals {
  # Sorted so a newly launched AZ does not change the selection.
  az_ids = length(var.az_ids) > 0 ? var.az_ids : slice(sort(data.aws_availability_zones.shared.zone_ids), 0, 2)

  consumer_account_ids = {
    payments  = data.aws_caller_identity.payments.account_id
    analytics = data.aws_caller_identity.analytics.account_id
  }
}

module "shared_services_network" {
  source    = "./modules/network"
  providers = { aws = aws.shared }

  name                    = "${var.name_prefix}-shared-services"
  cidr_block              = var.vpc_cidrs.shared
  az_ids                  = local.az_ids
  flow_log_retention_days = var.flow_log_retention_days
}

module "payments_network" {
  source    = "./modules/network"
  providers = { aws = aws.payments }

  name                    = "${var.name_prefix}-payments"
  cidr_block              = var.vpc_cidrs.payments
  az_ids                  = local.az_ids
  flow_log_retention_days = var.flow_log_retention_days
}

module "analytics_network" {
  source    = "./modules/network"
  providers = { aws = aws.analytics }

  name                    = "${var.name_prefix}-analytics"
  cidr_block              = var.vpc_cidrs.analytics
  az_ids                  = local.az_ids
  flow_log_retention_days = var.flow_log_retention_days
}

module "shared_service" {
  source    = "./modules/service-provider"
  providers = { aws = aws.shared }

  name       = "${var.name_prefix}-shared"
  vpc_id     = module.shared_services_network.vpc_id
  subnet_ids = module.shared_services_network.private_subnet_ids

  service_port     = var.service_port
  service_hostname = var.service_hostname
  instance_type    = var.app_instance_type
  instance_count   = var.app_instance_count
  alarm_actions    = var.alarm_actions

  consumer_cidrs = {
    payments  = var.vpc_cidrs.payments
    analytics = var.vpc_cidrs.analytics
  }

  allowed_principal_arns = toset([
    for account_id in values(local.consumer_account_ids) :
    "arn:${data.aws_partition.current.partition}:iam::${account_id}:root"
  ])
}

module "payments_consumer" {
  source    = "./modules/service-consumer"
  providers = { aws = aws.payments }

  name               = "${var.name_prefix}-payments"
  vpc_id             = module.payments_network.vpc_id
  subnet_ids         = module.payments_network.private_subnet_ids
  service_name       = module.shared_service.service_name
  service_port       = var.service_port
  service_hostname   = var.service_hostname
  create_test_client = var.create_test_clients
}

module "analytics_consumer" {
  source    = "./modules/service-consumer"
  providers = { aws = aws.analytics }

  name               = "${var.name_prefix}-analytics"
  vpc_id             = module.analytics_network.vpc_id
  subnet_ids         = module.analytics_network.private_subnet_ids
  service_name       = module.shared_service.service_name
  service_port       = var.service_port
  service_hostname   = var.service_hostname
  create_test_client = var.create_test_clients
}

# Each entry is an approval. Remove one to revoke that consumer.
resource "aws_vpc_endpoint_connection_accepter" "consumers" {
  provider = aws.shared

  for_each = {
    payments  = module.payments_consumer.endpoint_id
    analytics = module.analytics_consumer.endpoint_id
  }

  vpc_endpoint_service_id = module.shared_service.service_id
  vpc_endpoint_id         = each.value
}
