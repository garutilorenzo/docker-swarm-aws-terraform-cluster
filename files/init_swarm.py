#!/usr/bin/env python3

import docker
import json
import boto3
from botocore.exceptions import ClientError
import requests
import argparse
from typing import Tuple, Dict, Any, List, Optional
import logging
import sys
from datetime import datetime
import time

METADATA_URL = "http://169.254.169.254/latest"
TOKEN_URL = f"{METADATA_URL}/api/token"
HEADERS = {"X-aws-ec2-metadata-token-ttl-seconds": "21600"}

docker_client  = docker.APIClient()

class JsonStdoutHandler(logging.StreamHandler):
    def emit(self, record: logging.LogRecord) -> None:
        log_entry = {
            "timestamp": datetime.fromtimestamp(record.created).isoformat(),
            "level": record.levelname.lower(),
            "message": record.getMessage()
        }
        sys.stdout.write(json.dumps(log_entry) + "\n")

def setup_logging() -> None:
    plain_formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    file_handler = logging.FileHandler('/var/log/swarm_init.log')
    file_handler.setFormatter(plain_formatter)
    file_handler.setLevel(logging.INFO)

    json_handler = JsonStdoutHandler()
    json_handler.setLevel(logging.INFO)

    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(file_handler)
    root_logger.addHandler(json_handler)

setup_logging()
logger = logging.getLogger(__name__)

def get_token() -> str:
    try:
        response = requests.put(TOKEN_URL, headers=HEADERS, timeout=2)
        response.raise_for_status()
        logger.info("Fetched EC2 metadata token successfully.")
        return response.text
    except Exception as e:
        logger.error(f"Failed to fetch EC2 metadata token: {e}")
        raise

def get_metadata(token: str, path: str) -> str:
    try:
        metadata_headers = {"X-aws-ec2-metadata-token": token}
        response = requests.get(f"{METADATA_URL}/meta-data/{path}", headers=metadata_headers, timeout=2)
        response.raise_for_status()
        logger.info(f"Fetched metadata for path: {path}")
        return response.text
    except Exception as e:
        logger.error(f"Failed to fetch metadata for path {path}: {e}")
        raise

def fetch_instance_info() -> Tuple[str, str, str]:
    token = get_token()
    private_ip = get_metadata(token, "local-ipv4")
    instance_id = get_metadata(token, "instance-id")
    region = get_metadata(token, "placement/region")
    logger.info(f"Instance info: IP={private_ip}, ID={instance_id}, Region={region}")
    return private_ip, region, instance_id

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

def init_swarm(private_ip: str) -> Tuple[str, str]:
    details = get_swarm_details()
    response = None
    if details.get('ID'):
        JoinTokens = details.get('JoinTokens', {})
        json_tokens = json.dumps(JoinTokens) 
    else:
        logger.info("Initializing swarm...")
        try:
            response = docker_client.init_swarm(advertise_addr=private_ip, listen_addr=private_ip)
        except Exception as e:
            logger.error(f"Failed to join swarm: {e}")  
        details = get_swarm_details() 
        if details.get('ID'):
            JoinTokens = details.get('JoinTokens', {})
            json_tokens = json.dumps(JoinTokens) 
    return response, json_tokens

def join_swarm(remote_addrs: List[str], private_ip: str, join_token: str) -> Tuple[str, str]:
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
        except Exception as e:
            logger.error(f"Failed to join swarm: {e}")  
    return response, SwarnNodeId

def get_instances_from_tag(region_name: str, tag_key: str) -> List[str]:
    ec2_client = boto3.client("ec2", region_name=region_name)
    try:
        response = ec2_client.describe_instances(
            Filters=[
                {"Name": "tag-key", "Values": [tag_key]},
                {"Name": "instance-state-name", "Values": ["running"]}
            ]
        )
        instances = [
            instance
            for reservation in response["Reservations"]
            for instance in reservation["Instances"]
        ]
        if not instances:
            logger.info(f"No instances with tag key '{tag_key}' found.")
            return []
        logger.info(f"Found {len(instances)} instances with tag key '{tag_key}'.")
        return instances
    except ClientError as e:
        logger.error(f"Error fetching instances: {e}")
        return []

def get_oldest_instance_running(region_name: str, tag_key: str) -> Optional[str]:
    oldest_instance: Optional[str] = None
    instances: List[str] = []
    while not instances:
        instances = get_instances_from_tag(region_name, tag_key)
        if not instances:
            logger.info("Waiting for instances with tag key '%s'...", tag_key)
            time.sleep(5)
    instances_sorted = sorted(instances, key=lambda x: x["LaunchTime"])
    if len(instances_sorted) > 1:
        selected_instance = instances_sorted[:-1][0]
    else:
        logger.info("Only one instance found. Skipping the most recent filter.")
        selected_instance = instances_sorted[0]
    oldest_instance = selected_instance["InstanceId"]
    logger.info(f"Oldest running instance: {oldest_instance}")
    return oldest_instance

def get_manager_ips(region_name: str, tag_key: str) -> List[str]:
    instances_ips: List[str] = []
    instances: List[str] = []
    while not instances:
        instances = get_instances_from_tag(region_name, tag_key)
        if not instances:
            logger.info("Waiting for instances with tag key '%s'...", tag_key)
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
    
    private_ip, region, instance_id = fetch_instance_info()
    oldest_instance = get_oldest_instance_running(region, manager_tag)
    instance_tags = get_instance_tags(instance_id, region)
    is_manager = any(tag['Key'] == manager_tag for tag in instance_tags)
    is_worker = any(tag['Key'] == worker_tag for tag in instance_tags)

    SwarnNodeId = get_node_details()
    if SwarnNodeId:
        logger.info(f"Already part of a swarm cluster with ID: {SwarnNodeId}")
        return
    
    if oldest_instance == instance_id:
        init_swarm_response, join_tokens = init_swarm(private_ip)
        if join_tokens:
            upload_to_secrets_manager(secret_name, join_tokens, region)
    else:
        remote_addrs = get_manager_ips(region, manager_tag)
        join_token: Dict[str, Any] = {}
        while not join_token:
            join_token = download_from_secrets_manager(secret_name, region)
            logger.info(f"Waiting for join token from Secrets Manager...")
            time.sleep(5)
        if join_token and is_worker:
            logger.info(f"Joining swarm as worker with token: {join_token.get('Worker', '')}")
            while not join_worker_response:
                join_worker_response, SwarnNodeId = join_swarm(remote_addrs, private_ip, join_token.get('Worker', ''))
        elif join_token and is_manager:
            logger.info(f"Joining swarm as manager with token: {join_token.get('Manager', '')}")
            while not join_manager_response:
                join_manager_response, SwarnNodeId = join_swarm(remote_addrs, private_ip, join_token.get('Manager', ''))
        else:
            logger.error("No join token found in Secrets Manager.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Initialize or join Docker Swarm on EC2.")
    parser.add_argument("--secret_name", required=True, type=str, help="Name of the AWS Secrets Manager secret.")
    parser.add_argument("--manager_tag", required=True, type=str, help="Tag key for manager instances.")
    parser.add_argument("--worker_tag", required=True, type=str, help="Tag key for worker instances.")
    args = parser.parse_args()
    main(args.secret_name, args.manager_tag, args.worker_tag)