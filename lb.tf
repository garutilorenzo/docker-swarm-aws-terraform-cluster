resource "aws_lb" "external_lb" {
  count              = var.create_extlb ? 1 : 0
  name               = "${local.common_prefix}-ext-lb"
  load_balancer_type = "network"
  internal           = "false"
  subnets            = var.vpc_public_subnets

  enable_cross_zone_load_balancing = true

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ext-lb")
    }
  )
}

# HTTP
resource "aws_lb_listener" "external_lb_listener_http" {
  count             = var.create_extlb ? 1 : 0
  load_balancer_arn = aws_lb.external_lb[count.index].arn

  protocol = "TCP"
  port     = var.extlb_http_port

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external_lb_tg_http[count.index].arn
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-http-listener")
    }
  )
}

resource "aws_lb_target_group" "external_lb_tg_http" {
  count             = var.create_extlb ? 1 : 0
  port              = var.extlb_http_port
  protocol          = "TCP"
  vpc_id            = var.vpc_id
  proxy_protocol_v2 = true

  depends_on = [
    aws_lb.external_lb
  ]

  health_check {
    protocol = "TCP"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ext-lb-tg-http")
    }
  )
}

resource "aws_autoscaling_attachment" "target_http" {
  count = var.create_extlb ? 1 : 0
  depends_on = [
    aws_autoscaling_group.docker_swarm_workers_asg,
    aws_lb_target_group.external_lb_tg_http
  ]

  autoscaling_group_name = aws_autoscaling_group.docker_swarm_workers_asg.name
  lb_target_group_arn    = aws_lb_target_group.external_lb_tg_http[count.index].arn
}

# HTTPS
resource "aws_lb_listener" "external_lb_listener_https" {
  count             = var.create_extlb ? 1 : 0
  load_balancer_arn = aws_lb.external_lb[count.index].arn

  protocol = "TCP"
  port     = var.extlb_https_port

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external_lb_tg_https[count.index].arn
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-https-listener")
    }
  )
}

resource "aws_lb_target_group" "external_lb_tg_https" {
  count             = var.create_extlb ? 1 : 0
  port              = var.extlb_https_port
  protocol          = "TCP"
  vpc_id            = var.vpc_id
  proxy_protocol_v2 = true

  depends_on = [
    aws_lb.external_lb
  ]

  health_check {
    protocol = "TCP"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ext-lb-tg-https")
    }
  )
}

resource "aws_autoscaling_attachment" "target_https" {
  count = var.create_extlb ? 1 : 0
  depends_on = [
    aws_autoscaling_group.docker_swarm_workers_asg,
    aws_lb_target_group.external_lb_tg_https
  ]

  autoscaling_group_name = aws_autoscaling_group.docker_swarm_workers_asg.name
  lb_target_group_arn    = aws_lb_target_group.external_lb_tg_https[count.index].arn
}

######################
### Security Group ###
######################

resource "aws_security_group" "public_lb_sg" {
  count       = var.create_extlb ? 1 : 0
  vpc_id      = var.vpc_id
  name        = "${local.common_prefix}-public-lb-sg"
  description = "Allow http and https traffic to the public load balancer from the internet"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-public-lb-sg")
    }
  )
}

resource "aws_security_group_rule" "public_lb_allow_lb_http_traffic" {
  count             = var.create_extlb ? 1 : 0
  description       = "Allow incoming HTTP traffic from the internet"
  type              = "ingress"
  from_port         = var.extlb_http_port
  to_port           = var.extlb_http_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_lb_sg[count.index].id
}

resource "aws_security_group_rule" "public_lb_allow_lb_https_traffic" {
  count             = var.create_extlb ? 1 : 0
  description       = "Allow incoming HTTPS traffic from the internet"
  type              = "ingress"
  from_port         = var.extlb_https_port
  to_port           = var.extlb_https_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_lb_sg[count.index].id
}

resource "aws_security_group_rule" "public_lb_egress_all" {
  count             = var.create_extlb ? 1 : 0
  description       = "Allow egress traffic to all destinations"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.public_lb_sg[count.index].id
}