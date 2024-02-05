[![GitHub issues](https://img.shields.io/github/issues/garutilorenzo/k3s-aws-terraform-cluster)](https://github.com/garutilorenzo/k3s-aws-terraform-cluster/issues)
![GitHub](https://img.shields.io/github/license/garutilorenzo/k3s-aws-terraform-cluster)
[![GitHub forks](https://img.shields.io/github/forks/garutilorenzo/k3s-aws-terraform-cluster)](https://github.com/garutilorenzo/k3s-aws-terraform-cluster/network)
[![GitHub stars](https://img.shields.io/github/stars/garutilorenzo/k3s-aws-terraform-cluster)](https://github.com/garutilorenzo/k3s-aws-terraform-cluster/stargazers)

# Deploy Docker Swarm on Amazon AWS

Deploy in a few minutes an high available [Docker Swarm](https://docs.docker.com/engine/swarm/) cluster on Amazon AWS using mixed on-demand and spot instances.

# Table of Contents

- [Deploy Docker Swarm on Amazon AWS](#deploy-docker-swarm-on-amazon-aws)
- [Table of Contents](#table-of-contents)
  - [Requirements](#requirements)
  - [Before you start](#before-you-start)
  - [Pre flight checklist](#pre-flight-checklist)
  - [Clean up](#clean-up)

## Requirements

* [Terraform](https://www.terraform.io/) - Terraform is an open-source infrastructure as code software tool that provides a consistent CLI workflow to manage hundreds of cloud services. Terraform codifies cloud APIs into declarative configuration files.
* [Amazon AWS Account](https://aws.amazon.com/it/console/) - Amazon AWS account with billing enabled
* AWS private VPC with DNS support enabled. You can use [this](https://github.com/garutilorenzo/aws-terraform-examples) terraform module.

## Before you start

Note that this tutorial uses AWS resources that are outside the AWS free tier, so be careful!

## Pre flight checklist

Follow the prerequisites step on [this](https://learn.hashicorp.com/tutorials/terraform/aws-build?in=terraform/aws-get-started) link.
Create a file named terraform.tfvars on the root of this repository and add your AWS_ACCESS_KEY and AWS_SECRET_KEY, example:

```
AWS_ACCESS_KEY = "xxxxxxxxxxxxxxxxx"
AWS_SECRET_KEY = "xxxxxxxxxxxxxxxxx"
```

edit the main.tf file under the [examples](examples/) folder and set the following variables:

| Var   | Required | Desc |
| ------- | ------- | ----------- |
| `AWS_REGION`       | `yes`       | set the correct aws region based on your needs  |
| `environment`  | `yes`  | Current work environment (Example: staging/dev/prod). This value is used for tag all the deployed resources |
| `ssk_key_pair_name`  | `yes`  | Name of the ssh key to use |
| `my_public_ip_cidr` | `yes`        |  your public ip in cidr format (Example: 195.102.xxx.xxx/32) |
| `vpc_subnet_cidr`  | `yes`  |  Your subnet CIDR. You can find the VPC subnet CIDR in your AWS console (Example: 172.31.0.0/16) |
| `vpc_id`  | `yes`  |  ID of the VPC to use. You can find your vpc_id in your AWS console (Example: vpc-xxxxx) |
| `vpc_private_subnets`  | `yes`  |  List of private subnets to use. This subnets are used for the public LB You can find the list of your vpc subnets in your AWS console (Example: subnet-xxxxxx) |
| `vpc_public_subnets`   | `yes`  |  List of public subnets to use. This subnets are used for the EC2 instances and the private LB. You can find the list of your vpc subnets in your AWS console (Example: subnet-xxxxxx) |
| `common_prefix`  | `no`  | Prefix used in all resource names/tags. Default: docker-swarm |
| `ec2_associate_public_ip_address`  | `no`  |  Assign or not a pulic ip to the EC2 instances. Default: false |
| `ami`  | `no`  | Ami image name. Default: ami-04807f3bd9aa6aab7 (eu-west-1), ubuntu 22.04 |
| `default_instance_type`  | `no`  | Default instance type used by the Launch template. Default: t3.medium |
| `instance_types`  | `no`  | Array of instances used by the ASG. Dfault: see `vars.tf` |
| `docker_swarm_manager_desired_capacity` | `no`        | Desired number of Dokcer swarm  managers. Default 3 |
| `docker_swarm_manager_min_capacity` | `no`        | Min number of Dokcer swarm managers: Default 4 |
| `docker_swarm_manager_max_capacity` | `no`        |  Max number of Dokcer swarm managers: Default 3 |
| `docker_swarm_worker_desired_capacity` | `no`        | Desired number of Dokcer swarm  workers. Default 3 |
| `docker_swarm_worker_min_capacity` | `no`        | Min number of Dokcer swarm workers: Default 4 |
| `docker_swarm_worker_max_capacity` | `no`        | Max number of Dokcer swarm workers: Default 3 |
| `cluster_name`  | `no`  | Docker swarm cluster name used in AWS resource tagging. Defailt: ExampleCluster  |

## Clean up

```
terraform destroy
```