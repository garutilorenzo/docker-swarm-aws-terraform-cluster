locals {
  docker_swarm_join_manager_secret_name = "${var.common_prefix}-join-token-manager/${var.cluster_name}/${var.environment}/v1"
  docker_swarm_join_worker_secret_name  = "${var.common_prefix}-join-token-worker/${var.cluster_name}/${var.environment}/v1"
  global_tags = {
    environment               = "${var.environment}"
    provisioner               = "terraform"
    terraform_module          = "TOBEDONE"
    application               = "docker-swarm"
    docker_swarm_cluster_name = "${var.cluster_name}"
  }
}