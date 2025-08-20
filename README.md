[![GitHub issues](https://img.shields.io/github/issues/garutilorenzo/docker-swarm-aws-terraform-cluster)](https://github.com/garutilorenzo/docker-swarm-aws-terraform-cluster/issues)
![GitHub](https://img.shields.io/github/license/garutilorenzo/docker-swarm-aws-terraform-cluster)
[![GitHub forks](https://img.shields.io/github/forks/garutilorenzo/docker-swarm-aws-terraform-cluster)](https://github.com/garutilorenzo/docker-swarm-aws-terraform-cluster/network)
[![GitHub stars](https://img.shields.io/github/stars/garutilorenzo/docker-swarm-aws-terraform-cluster)](https://github.com/garutilorenzo/docker-swarm-aws-terraform-cluster/stargazers)

# Deploy Docker Swarm on Amazon AWS

Deploy in a few minutes an high available [Docker Swarm](https://docs.docker.com/engine/swarm/) cluster on Amazon AWS using mixed on-demand and spot instances.

# Table of Contents

- [Deploy Docker Swarm on Amazon AWS](#deploy-docker-swarm-on-amazon-aws)
- [Table of Contents](#table-of-contents)
  - [Requirements](#requirements)
  - [Before you start](#before-you-start)
  - [Pre flight checklist](#pre-flight-checklist)
  - [Notes about the infrastructure](#notes-about-the-infrastructure)
  - [Clean up](#clean-up)
  - [TBD](#tbd)

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

If you choose to deploy the public load balancer and you use the Application Load Balancer (default) you need a [public certificate](https://docs.aws.amazon.com/acm/latest/userguide/acm-public-certificates.html).
Once required and validated get the ARN and set the `alb_certificate_arn` variable of this module.

edit the main.tf file under the [examples](examples/) folder and set the following variables:

| Var   | Required | Desc |
| ------- | ------- | ----------- |
| `AWS_REGION`       | `yes`       | set the correct aws region based on your needs  |
| `environment`  | `yes`  | Current work environment (Example: staging/dev/prod). This value is used for tag all the deployed resources |
| `vpc_subnet_cidr`  | `yes`  |  Your subnet CIDR. You can find the VPC subnet CIDR in your AWS console (Example: 172.31.0.0/16) |
| `vpc_id`  | `yes`  |  ID of the VPC to use. You can find your vpc_id in your AWS console (Example: vpc-xxxxx) |
| `vpc_private_subnets`  | `yes`  |  List of private subnets to use. This subnets are used for the public LB You can find the list of your vpc subnets in your AWS console (Example: subnet-xxxxxx) |
| `vpc_public_subnets`   | `yes`  |  List of public subnets to use. This subnets are used for the EC2 instances and the private LB. You can find the list of your vpc subnets in your AWS console (Example: subnet-xxxxxx) |
| `common_prefix`  | `no`  | Prefix used in all resource names/tags. Default: `docker-swarm` |
| `ec2_associate_public_ip_address`  | `no`  |  Assign or not a pulic ip to the EC2 instances. Default: `false` |
| `ami`  | `no`  | Ami image name. Default: ami-04807f3bd9aa6aab7 (eu-west-1), ubuntu 22.04 |
| `default_instance_type`  | `no`  | Default instance type used by the Launch template. Default: `t3.medium` |
| `instance_types`  | `no`  | Array of instances used by the ASG. Dfault: see `vars.tf` |
| `docker_swarm_manager_tag`  | `no`  | Default tag for manager instances `docker-swarm-manager` |
| `docker_swarm_worker_tag`  | `no`  | Default tag for manager instances `docker-swarm-worker` |
| `docker_swarm_manager_desired_capacity` | `no`        | Desired number of Dokcer swarm  managers. Default `3` |
| `docker_swarm_manager_min_capacity` | `no`        | Min number of Dokcer swarm managers: Default `4` |
| `docker_swarm_manager_max_capacity` | `no`        |  Max number of Dokcer swarm managers: Default `3` |
| `docker_swarm_worker_desired_capacity` | `no`        | Desired number of Dokcer swarm  workers. Default `3` |
| `docker_swarm_worker_min_capacity` | `no`        | Min number of Dokcer swarm workers: Default `4` |
| `docker_swarm_worker_max_capacity` | `no`        | Max number of Dokcer swarm workers: Default `3` |
| `cluster_name`  | `no`  | Docker swarm cluster name used in AWS resource tagging. Default: `ExampleCluster`  |
| `my_public_ip_cidrs` | `no`        |  List of your public ip in cidr format (Example: 1.2.3.5/32) |
| `ssk_key_pair_name`  | `no`  | Name of the ssh key to use |
| `create_extlb`  | `no`  | Create public Load Balancer.  Default `false`. The load calancer can be of type `network` or `application` |
| `extlb_http_port`  | `no`  | Load baalancer HTTP listening port. Default `80` |
| `extlb_https_port`  | `no`  | Load baalancer HTTPS listening port. Default `443` |
| `load_balancer_type`  | `no`  | Load balancer type. Default `application`. |
| `alb_certificate_arn`  | `no`  | ARN of the HTTP certificate stored in Certificate Manager. Not managed by this module. Required if the load balancer type is `application` |
| `deploy_traefik`  | `no`  | Deploy [Traefik](https://traefik.io/traefik) http(s) ingress controller. Default `false` |
| `expose_traefik_dashboard`  | `no`  | Expose the Traefik dashboard |
| `traefik_dashboard_fqdn`  | `no`  | Traefik dashboard FQDN. Required if `expose_traefik_dashboard` is `true` |
| `traefik_dashboard_username`  | `no`  | Traefik dashboard username. Required if `expose_traefik_dashboard` is `true` |
| `traefik_dashboard_password`  | `no`  | Traefik dashboard password. Required if `expose_traefik_dashboard` is `true` |
| `traefik_dashboard_ip_whitelist`  | `no`  | Comma separated list of CIDRs to allow for dashboard access. Not required by highly recommended. |

## Notes about the infrastructure

All the docker daemons are configured with SSL. The CA is stored on secrets manager. The user data scirpt also create a client certificate that can be used to reach the swarm managers via TCP port 2376.

The join tokens are also stored on secrets manager and are automatically retrieved by the instances that tries to join the cluster.

Is it possible to deploy [Traefik](https://traefik.io/traefik) in this moment only Load balancer type `application` is supported. Is it possible to configure Traefik also for Load balancer type `network`.

## Clean up

```
terraform destroy
```

## TBD

This version of the infrastructure provides some EventBridge rules that capture EC2 interruptions and sends the events to an SQS queue. On a future release the messages will be parsed from a daemon (running directly on the nodes or a lambda funcion) to handle instance interruption (spot interruption, insance rebalance, instance state change, EC2 scheduled change)

Add support for Traefik and Network load balancer

Add EFS support for persistent storage