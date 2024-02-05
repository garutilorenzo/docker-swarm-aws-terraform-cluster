data "aws_region" "current" {}

data "aws_iam_policy" "AmazonEC2ReadOnlyAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "template_cloudinit_config" "docker_swarm_manager" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/files/cloud-config-base.yaml", {})
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/files/install_docker.sh", {})
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/docker_swarm.sh", {
      default_secret_placeholder            = var.default_secret_placeholder,
      docker_swarm_manager_tag_value        = var.docker_swarm_manager_tag_value,
      docker_swarm_join_manager_secret_name = local.docker_swarm_join_manager_secret_name
      docker_swarm_join_worker_secret_name  = local.docker_swarm_join_worker_secret_name
      docker_swarm_tag_key                  = var.docker_swarm_tag_key
      aws_region                            = data.aws_region.current.name
    })
  }
}

data "template_cloudinit_config" "docker_swarm_worker" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/files/cloud-config-base.yaml", {})
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/files/install_docker.sh", {})
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/docker_swarm.sh", {
      default_secret_placeholder            = var.default_secret_placeholder,
      docker_swarm_manager_tag_value        = var.docker_swarm_manager_tag_value,
      docker_swarm_join_manager_secret_name = local.docker_swarm_join_manager_secret_name
      docker_swarm_join_worker_secret_name  = local.docker_swarm_join_worker_secret_name
      docker_swarm_tag_key                  = var.docker_swarm_tag_key
      aws_region                            = data.aws_region.current.name
    })
  }
}

data "aws_instances" "docker_swarm_managers" {

  depends_on = [
    aws_autoscaling_group.docker_swarm_managers_asg,
  ]

  instance_tags = {
    for tag, value in merge(local.global_tags, { "${var.docker_swarm_tag_key}" = "${var.docker_swarm_manager_tag_value}" }) : tag => value
  }

  instance_state_names = ["running"]
}

data "aws_instances" "docker_swarm_workers" {

  depends_on = [
    aws_autoscaling_group.docker_swarm_workers_asg,
  ]

  instance_tags = {
    for tag, value in merge(local.global_tags, { "${var.docker_swarm_tag_key}" = "${var.docker_swarm_manager_tag_worker}" }) : tag => value
  }

  instance_state_names = ["running"]
}