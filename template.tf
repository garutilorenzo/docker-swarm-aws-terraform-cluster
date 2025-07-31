resource "aws_launch_template" "docker_swarm_manager" {
  name_prefix   = "${local.common_prefix}-manager-tpl"
  image_id      = var.ami
  instance_type = var.default_instance_type
  user_data     = data.template_cloudinit_config.docker_swarm_cloudinit.rendered

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
      "Name" = lower("${local.common_prefix}-manager-tpl")
    }
  )
}

resource "aws_launch_template" "docker_swarm_worker" {
  name_prefix   = "${local.common_prefix}-worker-tpl"
  image_id      = var.ami
  instance_type = var.default_instance_type
  user_data     = data.template_cloudinit_config.docker_swarm_cloudinit.rendered

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
      "Name" = lower("${local.common_prefix}-worker-tpl")
    }
  )
}