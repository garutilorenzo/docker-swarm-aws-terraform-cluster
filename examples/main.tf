variable "AWS_ACCESS_KEY" {}

variable "AWS_SECRET_KEY" {}

variable "environment" {
  default = "<CHANGE_ME>"
}

variable "AWS_REGION" {
  default = "<CHANGE_ME>"
}

variable "vpc_cidr_block" {
  default = "<CHANGE_ME>"
}

# eu-west-1
# Amazon Linux 2023 AMI 2023.8.20250721.2 x86_64 HVM kernel-6.1
# ami-0253a7ea84bc17a73

# Ubuntu 24.04 LTS (HVM), SSD Volume Type
# ami-01f23391a59163da9

# Choose the appropriate AMI for your region and architecture.
variable "ami" {
  default = "ami-0253a7ea84bc17a73"
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
  environment                    = var.environment
  vpc_id                         = module.private-vpc.vpc_id
  vpc_private_subnets            = module.private-vpc.private_subnet_ids
  vpc_public_subnets             = module.private-vpc.public_subnet_ids
  vpc_subnet_cidr                = var.vpc_cidr_block
  ami                            = var.ami
  # create_extlb                   = true
  # load_balancer_type             = "application" # "network"
  # deploy_traefik                 = true
  # expose_traefik_dashboard       = true
  # traefik_dashboard_fqdn         = "traefik.example.com"
  # traefik_dashboard_username     = "admin"
  # traefik_dashboard_password     = "pass"
  # traefik_dashboard_ip_whitelist = []
  # alb_certificate_arn            = "arn:aws:acm:<REGION>:<ACCOUNT_ID>:certificate/..."
  source                         = "../"
}

output "docker_swarm_manager_private_ips" {
  value = module.docker-swarm-cluster.docker_swarm_manager_private_ips
}

output "docker_swarm_workers_private_ips" {
  value = module.docker-swarm-cluster.docker_swarm_workers_private_ips
}