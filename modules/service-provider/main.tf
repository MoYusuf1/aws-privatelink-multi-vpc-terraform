data "aws_ssm_parameter" "al2023_ami" {
  name = var.ami_ssm_parameter
}

resource "aws_security_group" "nlb" {
  name        = "${var.name}-nlb"
  description = "Internal NLB fronting the shared application"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-nlb" }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Shared application instances. Reachable only from the NLB."
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-app" }
}

resource "aws_vpc_security_group_ingress_rule" "nlb_from_consumers" {
  for_each = var.consumer_cidrs

  security_group_id = aws_security_group.nlb.id
  description       = "Service port from consumer ${each.key}"
  ip_protocol       = "tcp"
  from_port         = var.service_port
  to_port           = var.service_port
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_app" {
  security_group_id            = aws_security_group.nlb.id
  description                  = "Forward and health check to app instances"
  ip_protocol                  = "tcp"
  from_port                    = var.service_port
  to_port                      = var.service_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_nlb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Service port from the NLB only"
  ip_protocol                  = "tcp"
  from_port                    = var.service_port
  to_port                      = var.service_port
  referenced_security_group_id = aws_security_group.nlb.id
}

# The app security group has no egress rules. The app never initiates connections.
resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-app-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 8
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
    service_hostname = var.service_hostname
    service_port     = var.service_port
    server_py        = file("${path.module}/app/server.py")
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-app" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name_prefix         = "${var.name}-app-"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.instance_count
  desired_capacity    = var.instance_count
  max_size            = var.instance_count * 2

  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }
}

resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_91:NLB access logs only cover TLS listeners. This listener is TCP passthrough; flow logs cover connections.
  #checkov:skip=CKV_AWS_150:Lab must tear down cleanly with terraform destroy. Production would set this via var.
  #checkov:skip=CKV2_AWS_20:Not an ALB. TLS is end to end, terminated on the instances.
  #checkov:skip=CKV2_AWS_28:WAF does not apply to Network Load Balancers.
  name               = substr("${var.name}-nlb", 0, 32)
  load_balancer_type = "network"
  internal           = true
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.nlb.id]

  enforce_security_group_inbound_rules_on_private_link_traffic = "on"

  # Trades inter-AZ transfer cost for tolerance of a single AZ losing its targets.
  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = var.deletion_protection

  tags = { Name = "${var.name}-nlb" }
}

resource "aws_lb_target_group" "app" {
  name_prefix = "app-"
  port        = var.service_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  # Passes the caller's VPC endpoint ID to the app.
  proxy_protocol_v2 = true

  deregistration_delay = 30

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "app" {
  #checkov:skip=CKV_AWS_2:TCP passthrough. TLS is terminated on the instances so traffic stays encrypted end to end.
  #checkov:skip=CKV_AWS_103:Same as above, TLS policy is enforced by the app on the instances.
  load_balancer_arn = aws_lb.this.arn
  port              = var.service_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_vpc_endpoint_service" "this" {
  acceptance_required        = true
  network_load_balancer_arns = [aws_lb.this.arn]
  supported_ip_address_types = ["ipv4"]

  tags = { Name = "${var.name}-endpoint-service" }
}

resource "aws_vpc_endpoint_service_allowed_principal" "consumers" {
  for_each = var.allowed_principal_arns

  vpc_endpoint_service_id = aws_vpc_endpoint_service.this.id
  principal_arn           = each.value
}

resource "aws_cloudwatch_metric_alarm" "healthy_hosts" {
  alarm_name          = "${var.name}-healthy-hosts-low"
  alarm_description   = "Fewer healthy app instances than desired behind the shared service NLB."
  namespace           = "AWS/NetworkELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  comparison_operator = "LessThanThreshold"
  threshold           = var.instance_count
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions
}
