#!/bin/bash

wait_for_join_token_to_be_created(){
  secret_name=$1
  res_join_secret_c=$(aws secretsmanager get-secret-value --secret-id $secret_name | jq -r .SecretString)
  while [[ -z "$res_join_secret_c" || "$res_join_secret_c" == "${default_secret_placeholder}" ]]
  do
    echo "Waiting the docker swarm join secret ..."
    res_join_secret_c=$(aws secretsmanager get-secret-value --secret-id $secret_name | jq -r .SecretString)
    sleep 1
  done
}

wait_for_secretsmanager(){
  secret_name=$1
  res_join_secret=$(aws secretsmanager get-secret-value --secret-id $secret_name | jq -r .SecretString)
  while [[ -z "$res_join_secret" ]]
  do
    echo "Waiting the docker swarm join secret ..."
    res_join_secret=$(aws secretsmanager get-secret-value --secret-id $secret_name | jq -r .SecretString)
    sleep 1
  done
}

main_manager(){
  wait_for_secretsmanager $docker_swarm_join_manager_secret_name
  join_token_manager=$(aws secretsmanager get-secret-value --secret-id ${docker_swarm_join_manager_secret_name} | jq -r .SecretString)
  if [[ "$first_instance" == "$instance_id" ]] && [[ "$join_token_manager" == "${default_secret_placeholder}" ]]; then
    echo "Init docker swarm cluster.."
    docker_advertise_addr=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4  -H "X-aws-ec2-metadata-token: $metadata_token")
    docker swarm init --advertise-addr $docker_advertise_addr
    join_token_manager=$(docker swarm join-token manager -q)
    join_token_worker=$(docker swarm join-token worker -q)

    aws secretsmanager update-secret --secret-id ${docker_swarm_join_manager_secret_name} --secret-string $join_token_manager
    aws secretsmanager update-secret --secret-id ${docker_swarm_join_worker_secret_name} --secret-string $join_token_worker
  else
    echo "Join manager.."
    wait_for_join_token_to_be_created $docker_swarm_join_manager_secret_name
    join_token_manager=$(aws secretsmanager get-secret-value --secret-id ${docker_swarm_join_manager_secret_name} | jq -r .SecretString)
    docker swarm join --token $join_token_manager $first_instance.${aws_region}.compute.internal
  fi
}

main_worker(){
  echo "Join worker.."
  wait_for_join_token_to_be_created $docker_swarm_join_worker_secret_name
  join_token_worker=$(aws secretsmanager get-secret-value --secret-id ${docker_swarm_join_worker_secret_name} | jq -r .SecretString)
  docker swarm join --token $join_token_worker $first_instance.${aws_region}.compute.internal
}

docker_swarm_join_manager_secret_name=${docker_swarm_join_manager_secret_name}
docker_swarm_join_worker_secret_name=${docker_swarm_join_worker_secret_name}

metadata_token=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id -H "X-aws-ec2-metadata-token: $metadata_token")
first_instance=$(aws ec2 describe-instances --filters Name=tag-value,Values=${docker_swarm_manager_tag_value} Name=instance-state-name,Values=running --query 'sort_by(Reservations[].Instances[], &LaunchTime)[:-1].[InstanceId]' --output text | head -n1)
docker_swarm_instance_type=$(aws ec2 describe-tags --filters Name=resource-id,Values=$instance_id Name=resource-type,Values=instance Name=key,Values=${docker_swarm_tag_key} | jq -r .Tags[0].Value)

if [[ "$docker_swarm_instance_type" == "${docker_swarm_manager_tag_value}" ]]; then
  main_manager
else
  main_worker
fi