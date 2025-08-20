#!/usr/bin/env python3
import os, json, base64, socket, ipaddress, time
import argparse
import logging

from pathlib import Path
from datetime import datetime, timedelta, timezone
from cryptography import x509
from cryptography.x509.oid import NameOID, ExtendedKeyUsageOID
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import rsa

import ec2_utils

# Directories
CERTS_DIR = Path("/etc/docker/certs")
CA_DIR = CERTS_DIR / "ca"
SERVER_DIR = CERTS_DIR / "server"
CLIENT_DIR = CERTS_DIR / "client"
DOCKER_OVERRIDE_DIR = Path("/etc/systemd/system/docker.service.d")
DOCKER_OVERRIDE_FILE = DOCKER_OVERRIDE_DIR / "override.conf"

ec2_utils.setup_logging(filename='/var/log/setup_docker_ssl_certs.log')
logger = logging.getLogger(__name__)

def wait_for_secret_ca(secret_name: str, timeout: int = 900, interval: int = 10) -> bool:
    """
    Wait until a secret exists in Secrets Manager and contains a non-empty 'ca' field.
    
    Args:
        secret_name: Name of the secret
        timeout: Maximum wait time in seconds
        interval: Time in seconds between checks
        
    Returns:
        True if 'ca' field is present before timeout, False otherwise
    """
    end_time = time.time() + timeout

    while time.time() < end_time:
        try:
            try:
                data = ec2_utils.download_from_secrets_manager(secret_name=secret_name)
            except json.JSONDecodeError:
                time.sleep(interval)
                continue
            if "ca" in data and data["ca"]:
                return True
        except Exception:
            time.sleep(interval)
            continue
        time.sleep(interval)
    return False

def check_secret_exists(secret_name: str) -> bool:
    """Check if a secret exists and has a 'ca' field."""
    try:
        data = ec2_utils.download_from_secrets_manager(secret_name=secret_name)
        return "ca" in data and data["ca"]
    except Exception:
        return False

def generate_private_key() -> rsa.RSAPrivateKey:
    return rsa.generate_private_key(public_exponent=65537, key_size=4096)

def save_pem_private_key(key: rsa.RSAPrivateKey, path: str) -> None:
    with open(path, "wb") as f:
        f.write(key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption()
        ))

def save_pem_cert(cert: x509.Certificate, path: str) -> None:
    with open(path, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))

def generate_ca_cert(ca_key: rsa.RSAPrivateKey) -> x509.Certificate:
    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, "DockerCA")
    ])
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(ca_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(datetime.now(timezone.utc))
        .not_valid_after(datetime.now(timezone.utc) + timedelta(days=3650))
        .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
        .sign(ca_key, hashes.SHA256())
    )
    return cert

def generate_client_cert(
    client_key: rsa.RSAPrivateKey, 
    ca_cert: x509.Certificate, 
    ca_key: rsa.RSAPrivateKey) -> x509.Certificate:

    subject = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, "client")
    ])
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(ca_cert.subject)
        .public_key(client_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(datetime.now(timezone.utc))
        .not_valid_after(datetime.now(timezone.utc) + timedelta(days=3650))
        .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.CLIENT_AUTH]), critical=False)
        .sign(ca_key, hashes.SHA256())
    )
    return cert

def generate_server_cert(
    server_key: rsa.RSAPrivateKey, 
    ca_cert: x509.Certificate, 
    ca_key: rsa.RSAPrivateKey, 
    hostname: str) -> x509.Certificate:

    subject = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, hostname)
    ])
    alt_names = [
        x509.DNSName(hostname),
        x509.IPAddress(ipaddress.IPv4Address("127.0.0.1")),
        x509.IPAddress(ipaddress.IPv4Address(socket.gethostbyname(hostname)))
    ]
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(ca_cert.subject)
        .public_key(server_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(datetime.now(timezone.utc))
        .not_valid_after(datetime.now(timezone.utc) + timedelta(days=3650))
        .add_extension(x509.SubjectAlternativeName(alt_names), critical=False)
        .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
        .sign(ca_key, hashes.SHA256())
    )
    return cert

def download_ca(secret_name: str) -> None:
    """Download CA cert and key from Secrets Manager."""
    data = ec2_utils.download_from_secrets_manager(secret_name=secret_name)

    with open(CA_DIR / "ca.pem", "wb") as f:
        f.write(base64.b64decode(data["ca"]))

    with open(CA_DIR / "ca-key.pem", "wb") as f:
        f.write(base64.b64decode(data["ca_key"]))

def download_client(secret_name: str) -> None:
    """Download CA cert and key from Secrets Manager."""
    data = ec2_utils.download_from_secrets_manager(secret_name=secret_name)

    with open(CLIENT_DIR / "cert.pem", "wb") as f:
        f.write(base64.b64decode(data["client"]))

    with open(CLIENT_DIR / "key.pem", "wb") as f:
        f.write(base64.b64decode(data["client_key"]))

def setup_client_cert(ca_secret_name: str, client_secret_name: str) -> None:
    user_docker_dir = Path.home() / ".docker"
    os.makedirs(user_docker_dir, exist_ok=True)
    data_ca = ec2_utils.download_from_secrets_manager(secret_name=ca_secret_name)
    with open(user_docker_dir / "ca.pem", "wb") as f:
        f.write(base64.b64decode(data_ca["ca"]))
    
    data_client = ec2_utils.download_from_secrets_manager(secret_name=client_secret_name)
    with open(user_docker_dir / "cert.pem", "wb") as f:
        f.write(base64.b64decode(data_client["client"]))
    with open(user_docker_dir / "key.pem", "wb") as f:
        f.write(base64.b64decode(data_client["client_key"]))

def set_file_permissions() -> None:
    """Match original Bash chmod calls."""
    os.chmod(CA_DIR / "ca-key.pem", 0o400)
    os.chmod(CA_DIR / "ca.pem", 0o444)
    if (CLIENT_DIR / "key.pem").exists():
        os.chmod(CLIENT_DIR / "key.pem", 0o400)
    if (CLIENT_DIR / "cert.pem").exists():
        os.chmod(CLIENT_DIR / "cert.pem", 0o444)
    os.chmod(SERVER_DIR / "server-key.pem", 0o400)
    os.chmod(SERVER_DIR / "server-cert.pem", 0o444)

def configure_docker_tls() -> None:
    """Create override.conf for Docker service."""
    DOCKER_OVERRIDE_DIR.mkdir(parents=True, exist_ok=True)
    with open(DOCKER_OVERRIDE_FILE, "w") as f:
        f.write(f"""[Service]
ExecStart=
ExecStart=/usr/bin/dockerd \\
  -H fd:// \\
  -H tcp://0.0.0.0:2376 \\
  --tlsverify \\
  --tlscacert={CA_DIR}/ca.pem \\
  --tlscert={SERVER_DIR}/server-cert.pem \\
  --tlskey={SERVER_DIR}/server-key.pem
""")

# -------------------
# Main
# -------------------
def main(ca_secret_name: str, client_secret_name: str, manager_tag: str) -> None:
    
    private_ip, region, instance_id = ec2_utils.fetch_instance_info()
    oldest_instance = ec2_utils.get_oldest_instance_running(tag_keys=[manager_tag])

    hostname = socket.gethostname()
    
    for d in (CA_DIR, SERVER_DIR, CLIENT_DIR):
        d.mkdir(parents=True, exist_ok=True)

    # Check if CA exists
    if check_secret_exists(ca_secret_name):
        logging.info("CA exists, downloading...")
        download_ca(ca_secret_name)
        with open(CA_DIR / "ca.pem", "rb") as f:
            ca_cert = x509.load_pem_x509_certificate(f.read())
        with open(CA_DIR / "ca-key.pem", "rb") as f:
            ca_key = serialization.load_pem_private_key(f.read(), password=None)
    else:
        if oldest_instance == instance_id:
            logging.info("Generating new CA...")
            ca_key = generate_private_key()
            ca_cert = generate_ca_cert(ca_key)
            save_pem_private_key(ca_key, CA_DIR / "ca-key.pem")
            save_pem_cert(ca_cert, CA_DIR / "ca.pem")

            ca_b64 = base64.b64encode(open(CA_DIR / "ca.pem", "rb").read()).decode()
            ca_key_b64 = base64.b64encode(open(CA_DIR / "ca-key.pem", "rb").read()).decode()
            ca_secret_value = json.dumps({"ca": ca_b64, "ca_key": ca_key_b64})
            ec2_utils.upload_to_secrets_manager(
                secret_name=ca_secret_name, 
                secret_value=ca_secret_value
            )

            logging.info("Generating client cert...")
            client_key = generate_private_key()
            client_cert = generate_client_cert(client_key, ca_cert, ca_key)
            save_pem_private_key(client_key, CLIENT_DIR / "key.pem")
            save_pem_cert(client_cert, CLIENT_DIR / "cert.pem")

            client_b64 = base64.b64encode(open(CLIENT_DIR / "cert.pem", "rb").read()).decode()
            client_key_b64 = base64.b64encode(open(CLIENT_DIR / "key.pem", "rb").read()).decode()
            client_secret_value = json.dumps({"client": client_b64, "client_key": client_key_b64})
            ec2_utils.upload_to_secrets_manager(
                secret_name=client_secret_name, 
                secret_value=client_secret_value
            )
        else:
            wait_for_secret_ca(secret_name=ca_secret_name)

    logging.info("Generating server cert...")
    server_key = generate_private_key()
    server_cert = generate_server_cert(server_key, ca_cert, ca_key, hostname)
    save_pem_private_key(server_key, SERVER_DIR / "server-key.pem")
    save_pem_cert(server_cert, SERVER_DIR / "server-cert.pem")

    logging.info("Docker TLS certs ready.")

    set_file_permissions()
    configure_docker_tls()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate and manage Docker TLS certs with AWS Secrets Manager.")
    parser.add_argument("--manager-tag", required=True, type=str, help="Tag key for manager instances.")
    parser.add_argument("--ca-secret-name", required=True, type=str, help="Name of the CA secret in AWS Secrets Manager.")
    parser.add_argument("--client-secret-name", required=True, type=str, help="Name of the client secret in AWS Secrets Manager.")
    parser.add_argument('--setup-client', action='store_true')
    
    args = parser.parse_args()    

    if args.setup_client:
        setup_client_cert(
            ca_secret_name=args.ca_secret_name,
            client_secret_name=args.client_secret_name
        )

    main(
        ca_secret_name=args.ca_secret_name, 
        client_secret_name=args.client_secret_name,
        manager_tag=args.manager_tag
    )