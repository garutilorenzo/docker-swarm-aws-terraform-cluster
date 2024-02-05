resource "aws_autoscaling_group" "docker_swarm_managers_asg" {
  name                      = "${var.common_prefix}-managers-asg-${var.environment}"
  wait_for_capacity_timeout = "5m"
  vpc_zone_identifier       = var.vpc_private_subnets

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns]
  }

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 20
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.docker_swarm_manager.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type     = override.value
          weighted_capacity = "1"
        }
      }
    }
  }

  desired_capacity          = var.docker_swarm_manager_desired_capacity
  min_size                  = var.docker_swarm_manager_min_capacity
  max_size                  = var.docker_swarm_manager_max_capacity
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

  dynamic "tag" {
    for_each = local.global_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.common_prefix}-manager-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = var.docker_swarm_tag_key
    value               = var.docker_swarm_manager_tag_value
    propagate_at_launch = true
  }

  depends_on = [
    aws_secretsmanager_secret.join_manager_secret,
    aws_secretsmanager_secret.join_worker_secret,
  ]
}

resource "aws_autoscaling_group" "docker_swarm_workers_asg" {
  name                = "${var.common_prefix}-workers-asg-${var.environment}"
  vpc_zone_identifier = var.vpc_private_subnets

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [load_balancers, target_group_arns]
  }

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 20
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.docker_swarm_worker.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.instance_types
        content {
          instance_type     = override.value
          weighted_capacity = "1"
        }
      }
    }
  }

  desired_capacity          = var.docker_swarm_worker_desired_capacity
  min_size                  = var.docker_swarm_worker_min_capacity
  max_size                  = var.docker_swarm_worker_max_capacity
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

  dynamic "tag" {
    for_each = local.global_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.common_prefix}-worker-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = var.docker_swarm_tag_key
    value               = var.docker_swarm_manager_tag_worker
    propagate_at_launch = true
  }

  depends_on = [
    aws_secretsmanager_secret.join_manager_secret,
    aws_secretsmanager_secret.join_worker_secret,
  ]
}