# One consuming team's side of the link: an interface endpoint in its own VPC, a private
# DNS name so callers keep using a stable hostname, and an optional test client.

locals {
  hostname_labels = split(".", var.service_hostname)
  # "app.shared.internal" -> zone "shared.internal"
  zone_name = join(".", slice(local.hostname_labels, 1, length(local.hostname_labels)))
}

data "aws_ssm_parameter" "al2023_ami" {
  count = var.create_test_client ? 1 : 0
  name  = var.ami_ssm_parameter
}

# ---------------------------------------------------------------------------
# Security groups
# ---------------------------------------------------------------------------

resource "aws_security_group" "client" {
  name        = "${var.name}-client"
  description = "Workloads in ${var.name} allowed to call the shared service"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-client" }
}

resource "aws_security_group" "endpoint" {
  name        = "${var.name}-shared-svc-endpoint"
  description = "Interface endpoint for the shared service"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-shared-svc-endpoint" }
}

resource "aws_vpc_security_group_egress_rule" "client_to_endpoint" {
  security_group_id            = aws_security_group.client.id
  description                  = "Call the shared service through the endpoint"
  ip_protocol                  = "tcp"
  from_port                    = var.service_port
  to_port                      = var.service_port
  referenced_security_group_id = aws_security_group.endpoint.id
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_client" {
  security_group_id            = aws_security_group.endpoint.id
  description                  = "Service port from approved client workloads only"
  ip_protocol                  = "tcp"
  from_port                    = var.service_port
  to_port                      = var.service_port
  referenced_security_group_id = aws_security_group.client.id
}

# ---------------------------------------------------------------------------
# Interface endpoint. It stays in pendingAcceptance until the service owner approves it.
# ---------------------------------------------------------------------------

resource "aws_vpc_endpoint" "shared_service" {
  vpc_id              = var.vpc_id
  service_name        = var.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = false

  tags = { Name = "${var.name}-shared-svc" }
}

# Private DNS without owning a public domain: a private hosted zone attached only to this
# VPC, with an alias to the endpoint. Callers use the same hostname in every consumer VPC.
resource "aws_route53_zone" "shared_service" {
  #checkov:skip=CKV2_AWS_38:DNSSEC signing is not supported for private hosted zones.
  #checkov:skip=CKV2_AWS_39:Query logging is not supported for private hosted zones. Resolver query logging would be the production option.
  name    = local.zone_name
  comment = "Private names for services consumed by ${var.name}"

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "shared_service" {
  zone_id = aws_route53_zone.shared_service.zone_id
  name    = var.service_hostname
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.shared_service.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.shared_service.dns_entry[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# ---------------------------------------------------------------------------
# Optional test client, reachable through an EC2 Instance Connect Endpoint (no public IP,
# no bastion, no extra charge).
# ---------------------------------------------------------------------------

resource "aws_security_group" "eice" {
  #checkov:skip=CKV2_AWS_5:False positive. Attached to aws_ec2_instance_connect_endpoint below, which checkov does not recognise.
  count = var.create_test_client ? 1 : 0

  name        = "${var.name}-instance-connect"
  description = "EC2 Instance Connect Endpoint for the test client"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-instance-connect" }
}

resource "aws_vpc_security_group_egress_rule" "eice_to_client" {
  count = var.create_test_client ? 1 : 0

  security_group_id            = aws_security_group.eice[0].id
  description                  = "SSH to the test client"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.client.id
}

resource "aws_vpc_security_group_ingress_rule" "client_from_eice" {
  #checkov:skip=CKV_AWS_24:False positive. The source is the Instance Connect Endpoint security group, not 0.0.0.0/0.
  count = var.create_test_client ? 1 : 0

  security_group_id            = aws_security_group.client.id
  description                  = "SSH from the Instance Connect Endpoint only"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.eice[0].id
}

resource "aws_ec2_instance_connect_endpoint" "this" {
  count = var.create_test_client ? 1 : 0

  subnet_id          = var.subnet_ids[0]
  security_group_ids = [aws_security_group.eice[0].id]

  # Source traffic from the endpoint itself so the client SG can reference the EICE SG.
  preserve_client_ip = false

  tags = { Name = "${var.name}-instance-connect" }
}

resource "aws_instance" "test_client" {
  #checkov:skip=CKV2_AWS_41:Test client needs no AWS API access, so it deliberately has no instance profile.
  #checkov:skip=CKV_AWS_126:Detailed monitoring is not worth the cost on a throwaway test client.
  count = var.create_test_client ? 1 : 0

  ami                    = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.client.id]
  ebs_optimized          = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  tags = { Name = "${var.name}-test-client" }
}
