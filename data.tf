data "aws_region" "current" {}

data "aws_iam_policy" "AmazonEC2ReadOnlyAccess" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy" "AutoScalingNotificationAccessRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
}

data "template_cloudinit_config" "docker_swarm_cloudinit" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/files/cloud-config-base.yaml", {
      ec2_utils_py_b64           = filebase64("${path.module}/files/ec2_utils.py")
      init_swarm_py_b64          = filebase64("${path.module}/files/init_swarm.py")
      setup_docker_ssl_certs_b64 = filebase64("${path.module}/files/setup_docker_ssl_certs.py")
    })
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/install_docker.sh", {
      docker_swarm_manager_tag      = var.docker_swarm_manager_tag,
      docker_swarm_worker_tag       = var.docker_swarm_worker_tag,
      docker_swarm_secret_name      = local.docker_swarm_secret_name
      docker_ca_ssl_secret_name     = local.docker_ca_ssl_secret_name
      docker_client_ssl_secret_name = local.docker_client_ssl_secret_name
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