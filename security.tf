resource "aws_security_group" "docker_swarm_sg" {
  vpc_id      = var.vpc_id
  name        = lower("${local.common_prefix}-allow-strict")
  description = "Allow strict access to the docker swarm cluster"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-allow-strict")
    }
  )
}

resource "aws_security_group_rule" "docker_swarm_ingress_self" {
  description       = "Allow traffic from the network itself"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.docker_swarm_sg.id
}

resource "aws_security_group_rule" "docker_swarm_ingress_ssh" {
  count             = length(var.my_public_ip_cidrs) > 0 ? 1 : 0
  description       = "Allow incoming SSH traffic for management IPs"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.my_public_ip_cidrs
  security_group_id = aws_security_group.docker_swarm_sg.id
}

resource "aws_security_group_rule" "docker_swarm_egress_all" {
  description       = "Allow egress traffic to all destinations"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.docker_swarm_sg.id
}

resource "aws_security_group_rule" "docker_swarm_ingress_from_lb_http" {
  count                    = var.create_extlb ? 1 : 0
  description              = "Allow incoming HTTP traffic from the public load balancer"
  type                     = "ingress"
  from_port                = var.extlb_http_port
  to_port                  = var.extlb_http_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.public_lb_sg[count.index].id
  security_group_id        = aws_security_group.docker_swarm_sg.id
}

resource "aws_security_group_rule" "docker_swarm_ingress_from_lb_https" {
  count                    = var.create_extlb ? 1 : 0
  description              = "Allow incoming HTTPS traffic from the public load balancer"
  type                     = "ingress"
  from_port                = var.extlb_https_port
  to_port                  = var.extlb_https_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.public_lb_sg[count.index].id
  security_group_id        = aws_security_group.docker_swarm_sg.id
}

# resource "aws_security_group" "efs_sg" {
#   count       = var.efs_persistent_storage ? 1 : 0
#   vpc_id      = var.vpc_id
#   name        = "${local.common_prefix}-efs-sg"
#   description = "Allow EFS access from VPC subnets"

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     from_port   = 2049
#     to_port     = 2049
#     protocol    = "tcp"
#     cidr_blocks = [var.vpc_subnet_cidr]
#   }

#   tags = merge(
#     local.global_tags,
#     {
#       "Name" = lower("${local.common_prefix}-efs-sg")
#     }
#   )
# }