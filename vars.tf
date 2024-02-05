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

variable "my_public_ip_cidr" {
  type        = string
  description = "My public ip CIDR"
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

## eu-west-1
# Ubuntu 22.04
# ami-04807f3bd9aa6aab7

# Amazon Linux 2 AMI (HVM) - Kernel 5.10, SSD Volume Type
# ami-006be9ab6a140de6e

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
    asg_instance_type_2 = "t3a.medium"
    asg_instance_type_3 = "c5.large"
    asg_instance_type_4 = "c6a.large"
    asg_instance_type_5 = "c6i.large"
    asg_instance_type_6 = "c7i.large"
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

variable "docker_swarm_tag_key" {
  type    = string
  default = "docker-swarm-instance-type"
}

variable "docker_swarm_manager_tag_value" {
  type    = string
  default = "docker-swarm-manager"
}

variable "docker_swarm_manager_tag_worker" {
  type    = string
  default = "docker-swarm-worker"
}

variable "default_secret_placeholder" {
  type    = string
  default = "DEFAULTPLACEHOLDER"
}

variable "cluster_name" {
  type        = string
  default     = "ExampleCluster"
  description = "Docker swarm cluster name used in AWS resource tagging"
}