locals {
  docker_swarm_secret_name = "${var.environment}/${local.common_prefix}-join-token/${var.cluster_name}/v1"
  common_prefix            = "${var.common_prefix}-${var.environment}"
  global_tags = {
    environment               = "${var.environment}"
    provisioner               = "terraform"
    terraform_module          = "garutilorenzo/docker-swarm-aws-terraform-cluster.git"
    application               = "docker-swarm"
    docker_swarm_cluster_name = "${var.cluster_name}"
  }
}