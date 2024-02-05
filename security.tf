resource "aws_security_group" "docker_swarm_sg" {
  vpc_id      = var.vpc_id
  name        = "docker_swarm_sg"
  description = "Docker Swarm ingress rules"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-allow-strict-${var.environment}")
    }
  )
}

resource "aws_security_group_rule" "ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = aws_security_group.docker_swarm_sg.id
}

resource "aws_security_group_rule" "ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.my_public_ip_cidr]
  security_group_id = aws_security_group.docker_swarm_sg.id
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.docker_swarm_sg.id
}

resource "aws_security_group_rule" "allow_lb_http_traffic" {
  count             = var.create_extlb ? 1 : 0
  type              = "ingress"
  from_port         = var.extlb_http_port
  to_port           = var.extlb_http_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.docker_swarm_sg.id
}

resource "aws_security_group_rule" "allow_lb_https_traffic" {
  count             = var.create_extlb ? 1 : 0
  type              = "ingress"
  from_port         = var.extlb_https_port
  to_port           = var.extlb_https_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.docker_swarm_sg.id
}

# resource "aws_security_group" "efs_sg" {
#   count       = var.efs_persistent_storage ? 1 : 0
#   vpc_id      = var.vpc_id
#   name        = "${var.common_prefix}-efs-sg-${var.environment}"
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
#       "Name" = lower("${var.common_prefix}-efs-sg-${var.environment}")
#     }
#   )
# }