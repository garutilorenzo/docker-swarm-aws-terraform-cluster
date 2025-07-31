data "aws_region" "current" {}

data "aws_iam_policy" "AmazonEC2ReadOnlyAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "template_cloudinit_config" "docker_swarm_cloudinit" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/files/cloud-config-base.yaml", {
      init_swarm_py_b64 = filebase64("${path.module}/files/init_swarm.py")
    })
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/install_docker.sh", {
      docker_swarm_manager_tag = var.docker_swarm_manager_tag,
      docker_swarm_worker_tag  = var.docker_swarm_worker_tag,
      docker_swarm_secret_name = local.docker_swarm_secret_name
    })
  }
}

data "aws_instances" "docker_swarm_managers" {

  depends_on = [
    aws_autoscaling_group.docker_swarm_managers_asg,
  ]

  instance_tags = {
    for tag, value in merge(local.global_tags, { "${var.docker_swarm_manager_tag}" = "true" }) : tag => value
  }

  instance_state_names = ["running"]
}

data "aws_instances" "docker_swarm_workers" {

  depends_on = [
    aws_autoscaling_group.docker_swarm_workers_asg,
  ]

  instance_tags = {
    for tag, value in merge(local.global_tags, { "${var.docker_swarm_worker_tag}" = "true" }) : tag => value
  }

  instance_state_names = ["running"]
}