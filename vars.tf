variable "environment" {
  type = string
}

variable "ssk_key_pair_name" {
  type = string
}

variable "vpc_id" {
  type        = string
  description = "The vpc id"
}

variable "my_public_ip_cidrs" {
  type        = list(string)
  default     = []
  description = "List of public IP CIDRs to allow"
}

variable "vpc_private_subnets" {
  type        = list(any)
  description = "The private vpc subnets ids"
}

variable "vpc_public_subnets" {
  type        = list(any)
  description = "The public vpc subnets ids"
}

variable "vpc_subnet_cidr" {
  type        = string
  description = "VPC subnet CIDR"
}

variable "common_prefix" {
  type        = string
  description = ""
  default     = "docker-swarm"
}

variable "ec2_associate_public_ip_address" {
  type    = bool
  default = false
}

variable "ami" {
  type    = string
  default = "ami-04807f3bd9aa6aab7"
}

variable "default_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Instance type to be used"
}

variable "instance_types" {
  description = "List of instance types to use"
  type        = map(string)
  default = {
    asg_instance_type_1 = "t3.medium"
    asg_instance_type_2 = "c5.large"
    asg_instance_type_3 = "c5d.large"
    asg_instance_type_4 = "c6i.large"
    asg_instance_type_5 = "c6id.large"
    asg_instance_type_6 = "c7i.large"
    asg_instance_type_7 = "c7i-flex.large"
  }
}

variable "docker_swarm_manager_desired_capacity" {
  type        = number
  default     = 3
  description = "Docker Swarm manager ASG desired capacity"
}

variable "docker_swarm_manager_min_capacity" {
  type        = number
  default     = 3
  description = "Docker Swarm manager ASG min capacity"
}

variable "docker_swarm_manager_max_capacity" {
  type        = number
  default     = 4
  description = "Docker Swarm manager ASG max capacity"
}

variable "docker_swarm_worker_desired_capacity" {
  type        = number
  default     = 3
  description = "Docker Swarm worker ASG desired capacity"
}

variable "docker_swarm_worker_min_capacity" {
  type        = number
  default     = 3
  description = "Docker Swarm worker ASG min capacity"
}

variable "docker_swarm_worker_max_capacity" {
  type        = number
  default     = 4
  description = "Docker Swarm worker ASG max capacity"
}

variable "create_extlb" {
  type        = bool
  default     = false
  description = "Create external LB true/false"
}

# variable "efs_persistent_storage" {
#   type    = bool
#   default = false
# }

variable "extlb_http_port" {
  type    = number
  default = 80
}

variable "extlb_https_port" {
  type    = number
  default = 443
}

variable "docker_swarm_manager_tag" {
  type    = string
  default = "docker-swarm-manager"
}

variable "docker_swarm_worker_tag" {
  type    = string
  default = "docker-swarm-worker"
}

variable "cluster_name" {
  type        = string
  default     = "ExampleCluster"
  description = "Docker swarm cluster name used in AWS resource tagging"
}

variable "load_balancer_type" {
  description = "Public load balancer type. Must be either 'network' or 'application'."
  type        = string
  default     = "network"

  validation {
    condition     = contains(["network", "application"], var.load_balancer_type)
    error_message = "The environment must be either 'network' or 'application'."
  }
}

variable "alb_certificate_arn" {
  description = "ARN of the ACM certificate. Required if load_balancer_type = application."
  type        = string
  default     = null

  validation {
    condition = (
      var.load_balancer_type != "application" ||
      (var.load_balancer_type == "application" && var.alb_certificate_arn != null && var.alb_certificate_arn != "")
    )
    error_message = "alb_certificate_arn must be set when load_balancer_type is 'application'."
  }
}

variable "deploy_traefik" {
  type        = bool
  default     = true
  description = "Deploy Traefik as a reverse proxy"
}

variable "expose_traefik_dashboard" {
  type        = bool
  default     = false
  description = "Expose Traefik dashboard"
}

variable "traefik_dashboard_fqdn" {
  type        = string
  default     = ""
  description = "FQDN for Traefik dashboard"

  validation {
    condition     = var.expose_traefik_dashboard ? (var.traefik_dashboard_fqdn != "") : true
    error_message = "traefik_dashboard_fqdn must be set when expose_traefik_dashboard is true."
  }
}

variable "traefik_dashboard_username" {
  type        = string
  default     = ""
  description = "Username for Traefik dashboard"

  validation {
    condition     = var.expose_traefik_dashboard ? (var.traefik_dashboard_username != "") : true
    error_message = "traefik_dashboard_username must be set when expose_traefik_dashboard is true."
  }
}

variable "traefik_dashboard_password" {
  type        = string
  default     = ""
  description = "Password for Traefik dashboard"

  validation {
    condition     = var.expose_traefik_dashboard ? (var.traefik_dashboard_password != "") : true
    error_message = "traefik_dashboard_password must be set when expose_traefik_dashboard is true."
  }
}

variable "traefik_dashboard_ip_whitelist" {
  type        = string
  default     = ""
  description = "Comma-separated list of IPs to whitelist for Traefik dashboard"
}