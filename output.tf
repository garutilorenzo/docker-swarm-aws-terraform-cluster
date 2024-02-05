# output "docker_swarm_dns_name" {
#   value = var.create_extlb ? aws_lb.external_lb.*.dns_name : []
# }

output "docker_swarm_manager_private_ips" {
  value = data.aws_instances.docker_swarm_managers.*.private_ips
}

output "docker_swarm_workers_private_ips" {
  value = data.aws_instances.docker_swarm_workers.*.private_ips
}