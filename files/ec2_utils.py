#!/usr/bin/env python3

from typing import Tuple, Dict, Any, List, Optional

import sys, json
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

import time
import requests
import logging

METADATA_URL = "http://169.254.169.254/latest"
TOKEN_URL = f"{METADATA_URL}/api/token"
HEADERS = {"X-aws-ec2-metadata-token-ttl-seconds": "21600"}

logger = logging.getLogger(__name__)

class JsonStdoutHandler(logging.StreamHandler):
    def emit(self, record: logging.LogRecord) -> None:
        log_entry = {
            "timestamp": datetime.fromtimestamp(record.created).isoformat(),
            "level": record.levelname.lower(),
            "message": record.getMessage()
        }
        sys.stdout.write(json.dumps(log_entry) + "\n")

def setup_logging(filename) -> None:
    plain_formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    file_handler = logging.FileHandler(filename)
    file_handler.setFormatter(plain_formatter)
    file_handler.setLevel(logging.INFO)

    json_handler = JsonStdoutHandler()
    json_handler.setLevel(logging.INFO)

    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    root_logger.addHandler(file_handler)
    root_logger.addHandler(json_handler)

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

def tag_instance(instance_id: str, region_name: str, tags: List[Dict[str, str]]) -> None:
    ec2_client = boto3.client("ec2", region_name=region_name)

    ec2_client.create_tags(
        Resources=[instance_id],
        Tags=tags
    )

def get_instances_from_tag(region_name: str, tag_keys: List[str]) -> List[str]:
    ec2_client = boto3.client("ec2", region_name=region_name)

    filters = [{"Name": "instance-state-name", "Values": ["running"]}]
    for tag in tag_keys:
        filters.append({"Name": "tag-key", "Values": [tag]})
    try:
        response = ec2_client.describe_instances(
            Filters=filters
        )
        instances = [
            instance
            for reservation in response["Reservations"]
            for instance in reservation["Instances"]
        ]
        if not instances:
            logger.info(f"No instances with tag key '{','.join(tag_keys)}' found.")
            return []
        logger.info(f"Found {len(instances)} instances with tag key '{','.join(tag_keys)}'.")
        return instances
    except ClientError as e:
        logger.error(f"Error fetching instances: {e}")
        return []

def get_oldest_instance_running(region_name: str, tag_keys: List[str]) -> Optional[str]:
    oldest_instance: Optional[str] = None
    instances: List[str] = []
    while not instances:
        instances = get_instances_from_tag(region_name=region_name, tag_keys=tag_keys)
        if not instances:
            logger.info("Waiting for instances with tag key '%s'...", ','.join(tag_keys))
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