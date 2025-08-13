#!/usr/bin/env python3

import docker
import json
import boto3
from botocore.exceptions import ClientError
import argparse
from typing import Tuple, Dict, Any, List, Optional
import logging
import time

import ec2_utils

docker_client  = docker.APIClient()

ec2_utils.setup_logging(filename='/var/log/swarm_init.log')
logger = logging.getLogger(__name__)

def upload_to_secrets_manager(secret_name: str, secret_value: str, region_name: str) -> Optional[Dict[str, Any]]:
    response: Dict[str, Any] = {}
    secrets_manager_client = boto3.client('secretsmanager', region_name=region_name)
    try:
        response = secrets_manager_client.put_secret_value(
            SecretId=secret_name,
            SecretString=secret_value
        )
        logger.info(f"Updated secret {secret_name} in region {region_name}.")
    except ClientError as e:
        logger.error(f"Error updating secret: {e}")
    return response

def download_from_secrets_manager(secret_name: str, region_name: str) -> Dict[str, Any]:
    result: Dict[str, Any] = {}
    secrets_manager_client = boto3.client('secretsmanager', region_name=region_name)
    try:
        response = secrets_manager_client.get_secret_value(
            SecretId=secret_name,
        )
        if response.get('SecretString'):
            logger.info(f"Trying to json loads {secret_name} from region {region_name}.")
            result = json.loads(response['SecretString'])
    except ClientError as e:
        logger.error(f"Error downloading secret {secret_name} or {secret_name} not in json format")
    return result

def get_swarm_details() -> Dict[str, Any]:
    try:
        details = docker_client.inspect_swarm()
        if details.get('ID'):
            logger.info(f"Swarm initialized with ID: {details['ID']}")
            return details
        else:
            logger.info("Swarm not initialized.")
            return {}
    except Exception as e:
        logger.error(f"Error inspecting swarm: {e}")
        return {}

def get_node_details() -> str:
    try:
        SwarnNodeId = docker_client.info()['Swarm']['NodeID']
        if SwarnNodeId:
            logger.info(f"Swarm initialized with ID: {SwarnNodeId}")
            return SwarnNodeId
        else:
            logger.info("Swarm not initialized.")
            return None
    except Exception as e:
        logger.error(f"Error inspecting swarm: {e}")
        return None

def init_swarm(private_ip: str, instance_id: str, region_name: str) -> Tuple[str, str]:
    details = get_swarm_details()
    response = None
    if details.get('ID'):
        JoinTokens = details.get('JoinTokens', {})
        json_tokens = json.dumps(JoinTokens) 
    else:
        logger.info("Initializing swarm...")
        try:
            response = docker_client.init_swarm(advertise_addr=private_ip, listen_addr=private_ip)
            tags = [
                {"Key": "docker-manager-deployed", "Value": "true"},
            ]
            ec2_utils.tag_instance(instance_id=instance_id, region_name=region_name, tags=tags) 
        except Exception as e:
            logger.error(f"Failed to init swarm: {e}")
        details = get_swarm_details() 
        if details.get('ID'):
            JoinTokens = details.get('JoinTokens', {})
            json_tokens = json.dumps(JoinTokens) 
    return response, json_tokens

def join_swarm(remote_addrs: List[str], private_ip: str, join_token: str, instance_id: str, region_name: str) -> Tuple[str, str]:
    SwarnNodeId = get_node_details()
    response = None
    if SwarnNodeId:
        logger.info(f"Already part of a swarm cluster with ID: {SwarnNodeId}")
    else:
        try:
            response = docker_client.join_swarm(
                join_token=join_token,
                remote_addrs=remote_addrs,
                advertise_addr=private_ip, 
                listen_addr=private_ip
            )
            logger.info(f"Joined swarm at {remote_addrs} as {private_ip}.")
            tags = [
                {"Key": "docker-worker-deployed", "Value": "true"},
            ]
            ec2_utils.tag_instance(instance_id=instance_id, region_name=region_name, tags=tags) 
        except Exception as e:
            logger.error(f"Failed to join swarm: {e}")
    return response, SwarnNodeId

def get_manager_ips(region_name: str, tag_keys: List[str]) -> List[str]:
    instances_ips: List[str] = []
    instances: List[str] = []
    while not instances:
        instances = ec2_utils.get_instances_from_tag(region_name=region_name, tag_keys=tag_keys)
        if not instances:
            logger.info("Waiting for instances with tag key '%s'...", ','.join(tag_keys))
            time.sleep(5)
    if instances:
        instances_ips = [i.get('PrivateIpAddress', '') for i in instances]
    return instances_ips

def get_instance_tags(instance_id: str, region: str) -> List[Dict[str, Any]]:
    ec2 = boto3.client("ec2", region_name=region)
    response = ec2.describe_instances(InstanceIds=[instance_id])
    tags = response["Reservations"][0]["Instances"][0].get("Tags", [])
    return tags

def main(secret_name: str, manager_tag: str, worker_tag: str) -> None:
    init_swarm_response, join_worker_response, join_manager_response = None, None, None
    
    private_ip, region, instance_id = ec2_utils.fetch_instance_info()
    oldest_instance = ec2_utils.get_oldest_instance_running(region_name=region, tag_keys=[manager_tag])
    instance_tags = get_instance_tags(instance_id, region)
    is_manager = any(tag['Key'] == manager_tag for tag in instance_tags)
    is_worker = any(tag['Key'] == worker_tag for tag in instance_tags)

    SwarnNodeId = get_node_details()
    if SwarnNodeId:
        logger.info(f"Already part of a swarm cluster with ID: {SwarnNodeId}")
        return
    
    if oldest_instance == instance_id:
        while not init_swarm_response:
            init_swarm_response, join_tokens = init_swarm(
                private_ip=private_ip, 
                instance_id=instance_id, 
                region_name=region
            )
        if join_tokens:
            upload_to_secrets_manager(secret_name=secret_name, secret_value=join_tokens, region_name=region)
    else:
        remote_addrs = get_manager_ips(
            region_name=region, 
            tag_keys=[manager_tag, 'docker-manager-deployed']
        )
        join_token_manager: str = ''
        join_token_worker: str = ''
        while not join_token_worker and not join_token_manager:
            join_token = download_from_secrets_manager(secret_name, region)
            join_token_worker = join_token.get('Worker', '')
            join_token_manager = join_token.get('Manager', '')
            logger.info(f"Waiting for join token from Secrets Manager...")
            time.sleep(5)
        
        if join_token_worker and is_worker:
            logger.info(f"Joining swarm as worker with token: {join_token_worker}")
            while not join_worker_response:
                join_worker_response, SwarnNodeId = join_swarm(
                    remote_addrs=remote_addrs, 
                    private_ip=private_ip, 
                    join_token=join_token_worker, 
                    instance_id=instance_id, 
                    region_name=region
                )
        elif join_token_manager and is_manager:
            logger.info(f"Joining swarm as manager with token: {join_token_manager}")
            while not join_manager_response:
                join_manager_response, SwarnNodeId = join_swarm(
                    remote_addrs=remote_addrs, 
                    private_ip=private_ip, 
                    join_token=join_token_manager, 
                    instance_id=instance_id, 
                    region_name=region
                )
        else:
            logger.error("No join token found in Secrets Manager.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Initialize or join Docker Swarm on EC2.")
    parser.add_argument("--secret_name", required=True, type=str, help="Name of the AWS Secrets Manager secret.")
    parser.add_argument("--manager_tag", required=True, type=str, help="Tag key for manager instances.")
    parser.add_argument("--worker_tag", required=True, type=str, help="Tag key for worker instances.")
    args = parser.parse_args()
    main(args.secret_name, args.manager_tag, args.worker_tag)