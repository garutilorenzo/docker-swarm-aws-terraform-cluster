#!/bin/bash

VENV_DIR=/opt/ec2-venv

check_os() {
  name=$(cat /etc/os-release | grep ^NAME= | sed 's/"//g')
  clean_name=$${name#*=}

  version=$(cat /etc/os-release | grep ^VERSION_ID= | sed 's/"//g')
  clean_version=$${version#*=}
  major=$${clean_version%.*}
  minor=$${clean_version#*.}
  
  if [[ "$${clean_name}" == "Ubuntu" ]]; then
    operating_system="ubuntu"
  elif [[ "$${clean_name}" == "Amazon Linux" ]]; then
    operating_system="amazonlinux"
  else
    operating_system="undef"
  fi

  echo "Install process running on: "
  echo "OS: $${operating_system}"
  echo "OS Major Release: $${major}"
  echo "OS Minor Release: $${minor}"
}

check_os

preflight_ubuntu(){
  apt-get update
  apt-get upgrade -y
  apt-get install -y curl jq unzip python3 python3-pip
}

install_docker_ubuntu(){
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # Add the repository to Apt sources:
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

preflight_amz(){
  dnf check-update
  dnf install -y jq unzip python3 python3-pip docker
}

install_aws_cli(){
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install --update
  rm -rf awscliv2.zip
  rm -rf aws
}

if [[ "$operating_system" == "ubuntu" ]]; then
  preflight_ubuntu
  install_docker_ubuntu
fi

if [[ "$operating_system" == "amazonlinux" ]]; then
  preflight_amz
fi

if [ ! -d "$${VENV_DIR}" ]; then
    echo "Creating Python venv in $${VENV_DIR}"
    python3 -m venv "$${VENV_DIR}"
fi

METADATA_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $METADATA_TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
export AWS_DEFAULT_REGION=$${AWS_REGION}
export AWS_REGION

$${VENV_DIR}/bin/pip3 install boto3 docker cryptography bcrypt

export PYTHONPATH=$${PYTHONPATH}:/usr/local/lib/
$${VENV_DIR}/bin/python /usr/local/sbin/setup_docker_ssl_certs.py --manager-tag ${docker_swarm_manager_tag} --ca-secret-name ${docker_ca_ssl_secret_name} --client-secret-name ${docker_client_ssl_secret_name}

systemctl daemon-reload
systemctl enable docker
systemctl restart docker

$${VENV_DIR}/bin/python /usr/local/sbin/init_swarm.py --secret-name ${docker_swarm_secret_name} --manager-tag ${docker_swarm_manager_tag} --worker-tag ${docker_swarm_worker_tag} 

%{ if deploy_traefik }
TRAEFIK_DASHBOARD_BLOCK="%{ if expose_traefik_dashboard }--expose-traefik-dashboard --traefik-dashboard-fqdn ${traefik_dashboard_fqdn} --traefik-dashboard-username ${traefik_dashboard_username} --traefik-dashboard-password ${traefik_dashboard_password}%{ endif }"
$${VENV_DIR}/bin/python /usr/local/sbin/deploy_traefik.py --manager-tag ${docker_swarm_manager_tag} --traefik-forwarded-headers-trusted-ips ${traefik_forwarded_headers_trusted_ips} $${TRAEFIK_DASHBOARD_BLOCK} %{ if traefik_dashboard_ip_whitelist != "" }--traefik-dashboard-ip-whitelist ${traefik_dashboard_ip_whitelist} %{ endif }
%{ endif }