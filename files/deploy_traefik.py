import argparse
import docker
import bcrypt
import os

import ec2_utils

MIDDLEWERE_AUTH_NAME = "traefik-auth"
MIDDLEWERE_IP_WHITELIST_NAME = "ip-whitelist"

# client = docker.from_env()
client = docker.APIClient()

def encrypt_password(password):
    bcrypted = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("utf-8")
    return bcrypted

def create_service(args):
    # --- Create network ---
    network_name = args.traefik_network_name
    try:
        client.create_network(name=network_name, driver="overlay", attachable=True)
        print(f"Network '{network_name}' created.")
    except docker.errors.APIError as e:
        if "already exists" in str(e):
            print(f"Network '{network_name}' already exists.")
        else:
            raise

    # --- Create Traefik service ---
    service_name = "traefik"
    image = f"traefik:{args.traefik_version}"

    # Command arguments
    container_command_args = [
        "--providers.swarm=true",
        "--providers.docker.endpoint=unix:///var/run/docker.sock",
        "--providers.docker.exposedbydefault=false",
        "--entrypoints.web.address=:80",
        "--api.dashboard=true",
        "--accesslog=true",
        "--log.level=INFO",
        "--ping=true",
        "--ping.entrypoint=web"
    ]
    if args.traefik_forwarded_headers_trusted_ips:
        container_command_args.append(f"--entrypoints.web.forwardedHeaders.trustedIPs=10.0.0.0/8,{args.traefik_forwarded_headers_trusted_ips}")

    # Ports mapping
    endpoint_spec = docker.types.EndpointSpec(ports={args.traefik_node_port: 80})

    # Mounts
    mounts = [docker.types.Mount(
        target="/var/run/docker.sock",
        source="/var/run/docker.sock",
        type="bind",
        read_only=True
    )]

    # Placement constraint
    placement = docker.types.Placement(constraints=["node.role == manager"])

    # Restart policy
    restart_policy = docker.types.RestartPolicy(condition="on-failure")

    # Healthcheck
    healthcheck = docker.types.Healthcheck(
        test=["CMD", "wget", "http://localhost:80/ping", "--spider"],
        interval=10_000_000_000,  # 10s in ns
        timeout=2_000_000_000,    # 2s in ns
        retries=3,
        start_period=5_000_000_000  # 5s in ns
    )

    # Labels (optional)
    labels = {}
    if args.expose_traefik_dashboard:
        if not (args.traefik_dashboard_fqdn and args.traefik_dashboard_username and args.traefik_dashboard_password):
            parser.error("--traefik-dashboard-fqdn, --traefik-dashboard-username and --traefik-dashboard-password are required when --expose-traefik-dashboard is set")

        hashed_pw = encrypt_password(args.traefik_dashboard_password)
        auth_middlewares = [MIDDLEWERE_AUTH_NAME]
        labels = {
            "traefik.enable": "true",
            "traefik.http.routers.traefik.rule": f"Host(`{args.traefik_dashboard_fqdn}`)",
            "traefik.http.routers.traefik.entrypoints": "web",
            "traefik.http.routers.traefik.service": "api@internal",
            "traefik.http.services.traefik.loadbalancer.server.port": "8080",
            f"traefik.http.middlewares.{MIDDLEWERE_AUTH_NAME}.basicauth.users": f"{args.traefik_dashboard_username}:{hashed_pw}",
        }
        if args.traefik_dashboard_ip_whitelist:
            labels[f"traefik.http.middlewares.{MIDDLEWERE_IP_WHITELIST_NAME}.ipallowlist.sourcerange"] = args.traefik_dashboard_ip_whitelist
            labels[f"traefik.http.middlewares.{MIDDLEWERE_IP_WHITELIST_NAME}.ipallowlist.ipstrategy.depth"] = "1"
            auth_middlewares.append(MIDDLEWERE_IP_WHITELIST_NAME)
        
        labels["traefik.http.routers.traefik.middlewares"] = ",".join(auth_middlewares)

    # Task template
    task_template = docker.types.TaskTemplate(
        container_spec=docker.types.ContainerSpec(
            image=image,
            args=container_command_args,
            mounts=mounts,
            healthcheck=healthcheck,
            labels=labels if labels else None
        ),
        restart_policy=restart_policy,
        placement=placement,
        networks=[docker.types.NetworkAttachmentConfig(target=network_name)]
    )

    # Deploy service
    try:
        client.create_service(
            name=service_name,
            task_template=task_template,
            mode=docker.types.ServiceMode("replicated", replicas=1),
            endpoint_spec=endpoint_spec,
            labels=labels if labels else None
        )
        print(f"Service '{service_name}' created.")
    except docker.errors.APIError as e:
        if "name already in use" in str(e):
            print(f"Service '{service_name}' already exists.")
        else:
            raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Deploy Traefik service with optional dashboard exposure")
    parser.add_argument("--expose-traefik-dashboard", action="store_true", help="Expose Traefik dashboard")
    parser.add_argument("--traefik-node-port", type=int, default=80, help="Traefik node port")
    parser.add_argument("--traefik-dashboard-fqdn", type=str, help="FQDN for Traefik dashboard")
    parser.add_argument("--traefik-dashboard-username", type=str, help="Username for Traefik dashboard")
    parser.add_argument("--traefik-dashboard-password", type=str, help="Password for Traefik dashboard")
    parser.add_argument("--traefik-dashboard-ip-whitelist", type=str, help="Comma-separated list of IPs to whitelist for Traefik dashboard")
    parser.add_argument("--traefik-network-name", type=str, default="traefik-network", help="Traefik network name")
    parser.add_argument("--traefik-version", type=str, default="v3.5", help="Traefik version to deploy")
    parser.add_argument("--traefik-forwarded-headers-trusted-ips", type=str, help="Comma-separated list of IPs to trust for forwarded headers (used for X-Forwarded-For)")
    parser.add_argument("--manager-tag", required=True, type=str, help="Tag key for manager instances.")
    args = parser.parse_args()

    private_ip, region, instance_id = ec2_utils.fetch_instance_info()
    instance_tags = ec2_utils.get_instance_tags(instance_id)
    is_manager = any(tag['Key'] == args.manager_tag for tag in instance_tags)
    if is_manager:
        create_service(args=args)