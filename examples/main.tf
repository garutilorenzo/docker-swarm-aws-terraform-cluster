variable "AWS_ACCESS_KEY" {}

variable "AWS_SECRET_KEY" {}

variable "environment" {
  default = "<CHANGE_ME>"
}

variable "AWS_REGION" {
  default = "<CHANGE_ME>"
}

variable "my_public_ip_cidr" {
  default = "<CHANGE_ME>"
}

variable "vpc_cidr_block" {
  default = "<CHANGE_ME>"
}

variable "ssk_key_pair_name" {
  default = "<CHANGE_ME>"
}

module "private-vpc" {
  region            = var.AWS_REGION
  my_public_ip_cidr = var.my_public_ip_cidr
  vpc_cidr_block    = var.vpc_cidr_block
  environment       = var.environment
  source            = "github.com/garutilorenzo/aws-terraform-examples/private-vpc"
}

output "private_subnets_ids" {
  value = module.private-vpc.private_subnet_ids
}

output "public_subnets_ids" {
  value = module.private-vpc.public_subnet_ids
}

output "vpc_id" {
  value = module.private-vpc.vpc_id
}

module "docker-swarm-cluster" {
  ssk_key_pair_name         = var.ssk_key_pair_name
  environment               = var.environment
  vpc_id                    = module.private-vpc.vpc_id
  vpc_private_subnets       = module.private-vpc.private_subnet_ids
  vpc_public_subnets        = module.private-vpc.public_subnet_ids
  vpc_subnet_cidr           = var.vpc_cidr_block
  my_public_ip_cidr         = var.my_public_ip_cidr
  source                    = "../"
}

output "docker_swarm_manager_private_ips" {
  value = module.docker-swarm-cluster.docker_swarm_manager_private_ips
}

output "docker_swarm_workers_private_ips" {
  value = module.docker-swarm-cluster.docker_swarm_workers_private_ips
}