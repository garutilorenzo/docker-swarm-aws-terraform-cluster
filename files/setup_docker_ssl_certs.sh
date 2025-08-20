#!/bin/bash

set -e

CERTS_DIR="/etc/docker/certs"
CA_DIR="$CERTS_DIR/ca"
SERVER_DIR="$CERTS_DIR/server"
CLIENT_DIR="$CERTS_DIR/client"
HOSTNAME="$(hostname)"
CA_SECRET_NAME="${1}"
CLIENT_SECRET_NAME="${2}"

if [ -z "$CA_SECRET_NAME" ] || [ -z "$CLIENT_SECRET_NAME" ]; then
  echo "Missing required positional arguments. Usage: $0 <ca_secret_name> <ca_key_secret_name> <client_secret_name> <client_key_secret_name>"
  exit 1
fi

METADATA_TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $METADATA_TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

mkdir -p "$CA_DIR" "$SERVER_DIR" "$CLIENT_DIR"

# Check existing secrets
check_secret_non_empty() {
  local secret_name=$1
  local secret_value

  set +e
  secret_value=$(aws secretsmanager get-secret-value \
    --secret-id "$secret_name" \
    --region "$AWS_REGION" \
    --query SecretString \
    --output text | jq -e 'has("ca")')
  set -e
  echo $secret_value

  if [[ $secret_value == false || $secret_value == "" ]];
  then
    return 1
  else
    return 0
  fi

}

NEED_CA_GEN=false

echo ">>> [0] Checking if CA secrets exist in Secrets Manager..."

if check_secret_non_empty "$CA_SECRET_NAME"; then
  echo "CA cert and key already exist in AWS Secrets Manager. Skipping CA generation."
else
  echo "CA secrets missing or empty — generating new CA..."
  NEED_CA_GEN=true
fi

if [ "$NEED_CA_GEN" = true ]; then
  echo ">>> [1/5] Generating CA..."
  openssl genrsa -out "$CA_DIR/ca-key.pem" 4096
  openssl req -x509 -new -nodes -key "$CA_DIR/ca-key.pem" -sha256 -days 3650 \
    -subj "/CN=DockerCA" -out "$CA_DIR/ca.pem"

  echo ">>> [2/5] Uploading CA to AWS Secrets Manager..."

  # Encode files in base64
  CA_B64=$(base64 -w 0 "$CA_DIR/ca.pem")
  CA_KEY_B64=$(base64 -w 0 "$CA_DIR/ca-key.pem")

  # Create JSON payload
  CA_SECRET_STRING=$(jq -n --arg ca "$CA_B64" --arg ca_key "$CA_KEY_B64" \
    '{ca: $ca, ca_key: $ca_key}')

  aws secretsmanager put-secret-value \
    --secret-id "$CA_SECRET_NAME" \
    --secret-string "$CA_SECRET_STRING" \
    --region "$AWS_REGION"
  
  echo "New CA cert and key uploaded to AWS Secrets Manager."

  echo ">>> [3/5] Generating client cert..."
  openssl genrsa -out "$CLIENT_DIR/key.pem" 4096
  openssl req -subj '/CN=client' -new -key "$CLIENT_DIR/key.pem" -out "$CLIENT_DIR/client.csr"

  cat > "$CLIENT_DIR/extfile.cnf" <<EOF
    extendedKeyUsage = clientAuth
EOF

  openssl x509 -req -in "$CLIENT_DIR/client.csr" -CA "$CA_DIR/ca.pem" -CAkey "$CA_DIR/ca-key.pem" \
    -CAcreateserial -out "$CLIENT_DIR/cert.pem" -days 3650 -sha256 \
    -extfile "$CLIENT_DIR/extfile.cnf"

  # Encode files in base64
  CLIETN_B64=$(base64 -w 0 "$CLIENT_DIR/cert.pem")
  CLIENT_KEY_B64=$(base64 -w 0 "$CLIENT_DIR/key.pem")

  # Create JSON payload
  CLIENT_SECRET_STRING=$(jq -n --arg client "$CLIETN_B64" --arg client_key "$CLIENT_KEY_B64" \
    '{client: $client, client_key: $client_key}')

  echo ">>> [4/5] Uploading Client certificates to AWS Secrets Manager..."
  
  # Upload client cert.pem
  aws secretsmanager put-secret-value \
    --secret-id "$CLIENT_SECRET_NAME" \
    --secret-string "$CLIENT_SECRET_STRING" \
    --region "$AWS_REGION"

  chmod 0400 "$CLIENT_DIR/key.pem" "$CA_DIR/ca-key.pem"
  chmod 0444 "$CLIENT_DIR/cert.pem" "$CA_DIR/ca.pem"
else
  echo "Downloading CA cert and key from AWS Secrets Manager..."

  aws secretsmanager get-secret-value \
    --secret-id $CA_SECRET_NAME \
    --region $AWS_REGION \
    --query SecretString \
    --output text | jq -r '.ca' | base64 -d > $CA_DIR/ca.pem

  aws secretsmanager get-secret-value \
    --secret-id $CA_SECRET_NAME \
    --region $AWS_REGION \
    --query SecretString \
    --output text | jq -r '.ca_key' | base64 -d > $CA_DIR/ca-key.pem
  
  chmod 0400 "$CA_DIR/ca-key.pem"
  chmod 0444 "$CA_DIR/ca.pem"
fi

echo ">>> [5/5] Generating server cert..."
openssl genrsa -out "$SERVER_DIR/server-key.pem" 4096
openssl req -new -key "$SERVER_DIR/server-key.pem" -subj "/CN=$HOSTNAME" \
  -out "$SERVER_DIR/server.csr"

cat > "$SERVER_DIR/extfile.cnf" <<EOF
subjectAltName = DNS:$HOSTNAME,IP:127.0.0.1,IP:$(hostname -I | awk '{print $1}')
extendedKeyUsage = serverAuth
EOF

openssl x509 -req -in "$SERVER_DIR/server.csr" -CA "$CA_DIR/ca.pem" -CAkey "$CA_DIR/ca-key.pem" \
  -CAcreateserial -out "$SERVER_DIR/server-cert.pem" -days 3650 -sha256 \
  -extfile "$SERVER_DIR/extfile.cnf"

chmod 0400 "$SERVER_DIR/server-key.pem"
chmod 0444 "$SERVER_DIR/server-cert.pem" "$CA_DIR/ca.pem"

echo "Docker TLS certs ready."

echo "Configuring Docker to use TLS"

mkdir -p /etc/systemd/system/docker.service.d

cat > /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd \\
  -H fd:// \\
  -H tcp://0.0.0.0:2376 \\
  --tlsverify \\
  --tlscacert=$CA_DIR/ca.pem \\
  --tlscert=$SERVER_DIR/server-cert.pem \\
  --tlskey=$SERVER_DIR/server-key.pem
EOF

systemctl daemon-reload
systemctl restart docker