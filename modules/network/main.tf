data "aws_caller_identity" "current" {}

resource "aws_vpc" "this" {
  cidr_block = var.cidr_block

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.name }
}

# Strips every rule from the default security group.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-default-do-not-use" }
}

# AZ IDs, not names, so every account lands in the same physical zones.
resource "aws_subnet" "private" {
  for_each = { for idx, az_id in var.az_ids : az_id => idx }

  vpc_id               = aws_vpc.this.id
  availability_zone_id = each.key
  cidr_block           = cidrsubnet(var.cidr_block, 8, each.value)

  map_public_ip_on_launch = false

  tags = { Name = "${var.name}-private-${each.key}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  #checkov:skip=CKV_AWS_158:Lab uses the AWS managed key to avoid a $1/month CMK per VPC. Production would use a CMK.
  #checkov:skip=CKV_AWS_338:Short retention keeps lab cost near zero. Retention is a variable.
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_log_retention_days
}

resource "aws_iam_role" "flow_logs" {
  name_prefix = "${var.name}-flow-logs-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "write-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn    = aws_iam_role.flow_logs.arn

  max_aggregation_interval = 60

  tags = { Name = "${var.name}-flow-logs" }
}
