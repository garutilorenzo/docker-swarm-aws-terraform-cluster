resource "aws_launch_template" "docker_swarm_manager" {
  name_prefix   = "${var.common_prefix}-manager-tpl-${var.environment}"
  image_id      = var.ami
  instance_type = var.default_instance_type
  user_data     = data.template_cloudinit_config.docker_swarm_manager.rendered

  lifecycle {
    create_before_destroy = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.docker_swarm_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 20
      encrypted   = true
    }
  }

  key_name = var.ssk_key_pair_name

  network_interfaces {
    associate_public_ip_address = var.ec2_associate_public_ip_address
    security_groups             = [aws_security_group.docker_swarm_sg.id]
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-manager-tpl-${var.environment}")
    }
  )
}

resource "aws_launch_template" "docker_swarm_worker" {
  name_prefix   = "${var.common_prefix}-worker-tpl-${var.environment}"
  image_id      = var.ami
  instance_type = var.default_instance_type
  user_data     = data.template_cloudinit_config.docker_swarm_worker.rendered

  lifecycle {
    create_before_destroy = true
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.docker_swarm_instance_profile.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 20
      encrypted   = true
    }
  }

  key_name = var.ssk_key_pair_name

  network_interfaces {
    associate_public_ip_address = var.ec2_associate_public_ip_address
    security_groups             = [aws_security_group.docker_swarm_sg.id]
  }

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-worker-tpl-${var.environment}")
    }
  )
}