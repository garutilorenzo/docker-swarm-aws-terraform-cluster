############################################
##### Main Load Balancer Configuration #####
############################################

resource "aws_lb" "external_lb" {
  count              = var.create_extlb ? 1 : 0
  name               = "${local.common_prefix}-ext-lb"
  load_balancer_type = var.load_balancer_type
  internal           = false
  subnets            = var.vpc_public_subnets
  security_groups = [
    aws_security_group.public_lb_sg[count.index].id
  ]

  enable_cross_zone_load_balancing = true

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ext-lb")
    }
  )
}

############################################
#####        HTTP CONFIGURATION        #####
############################################

# NLB listener: if the load_balancer_type is network we forward HTTP traffic to the target group
resource "aws_lb_listener" "external_nlb_listener_http" {
  count             = var.create_extlb && var.load_balancer_type == "network" ? 1 : 0
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

# ALB Listener: if the load_balancer_type is application we redirect HTTP traffic to HTTPS
resource "aws_lb_listener" "external_alb_listener_http" {
  count             = var.create_extlb && var.load_balancer_type == "application" ? 1 : 0
  load_balancer_arn = aws_lb.external_lb[count.index].arn

  port     = var.extlb_http_port
  protocol = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_302"
    }
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-http-listener")
    }
  )
}

# Dynamic config for the target group based on the load balancer typ
resource "aws_lb_target_group" "external_lb_tg_http" {
  count             = var.create_extlb ? 1 : 0
  port              = var.extlb_http_port
  protocol          = var.load_balancer_type == "application" ? "HTTP" : "TCP"
  vpc_id            = var.vpc_id
  proxy_protocol_v2 = var.load_balancer_type == "application" ? false : true

  depends_on = [
    aws_lb.external_lb
  ]

  health_check {
    protocol = var.load_balancer_type == "application" ? "HTTP" : "TCP"
    path     = var.load_balancer_type == "application" ? "/ping" : null
    matcher  = var.load_balancer_type == "application" ? 200 : null
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

############################################
#####        HTTPS CONFIGURATION       #####
############################################

# Dynamic config for the HTTPS listener based on the load balancer type
# If the load_balancer_type is application we use HTTPS and we configure the certificate_arn (external, not managed by this module)
# If the load_balancer_type is application we forward the HTTPS traffic to the target HTTP target group (Traefick will listen only on HTTP)

resource "aws_lb_listener" "external_lb_listener_https" {
  count             = var.create_extlb ? 1 : 0
  load_balancer_arn = aws_lb.external_lb[count.index].arn

  protocol        = var.load_balancer_type == "application" ? "HTTPS" : "TCP"
  certificate_arn = var.load_balancer_type == "application" ? var.alb_certificate_arn : null
  port            = var.extlb_https_port

  default_action {
    type             = "forward"
    target_group_arn = var.load_balancer_type == "application" ? aws_lb_target_group.external_lb_tg_http[count.index].arn : aws_lb_target_group.external_lb_tg_https[count.index].arn
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-https-listener")
    }
  )
}

# We need to create the HTTPS target group only if the load_balancer_type is network
resource "aws_lb_target_group" "external_lb_tg_https" {
  count             = var.create_extlb && var.load_balancer_type == "network" ? 1 : 0
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
  count = var.create_extlb && var.load_balancer_type == "network" ? 1 : 0
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