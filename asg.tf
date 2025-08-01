resource "aws_autoscaling_group" "docker_swarm_managers_asg" {
  name                      = "${local.common_prefix}-managers-asg"
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
    value               = "${local.common_prefix}-manager"
    propagate_at_launch = true
  }

  tag {
    key                 = var.docker_swarm_manager_tag
    value               = "true"
    propagate_at_launch = true
  }

  depends_on = [
    aws_secretsmanager_secret.join_secret,
  ]
}

resource "aws_autoscaling_group" "docker_swarm_workers_asg" {
  name                = "${local.common_prefix}-workers-asg"
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
    value               = "${local.common_prefix}-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = var.docker_swarm_worker_tag
    value               = "true"
    propagate_at_launch = true
  }

  depends_on = [
    aws_secretsmanager_secret.join_secret,
  ]
}

#######################################
# Lifecycle Hooks for ASG Termination #
#######################################

resource "aws_autoscaling_lifecycle_hook" "managers_term_hook" {
  name                   = "${local.common_prefix}-managers-term-hook"
  autoscaling_group_name = aws_autoscaling_group.docker_swarm_managers_asg.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  notification_target_arn = aws_sqs_queue.ec2_events_queue.arn
  role_arn                = aws_iam_role.notification_asg_iam_role.arn
}

resource "aws_autoscaling_lifecycle_hook" "workders_term_hook" {
  name                   = "${local.common_prefix}-workers-term-hook"
  autoscaling_group_name = aws_autoscaling_group.docker_swarm_workers_asg.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 300
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  notification_target_arn = aws_sqs_queue.ec2_events_queue.arn
  role_arn                = aws_iam_role.notification_asg_iam_role.arn
}