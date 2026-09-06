#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=================================================="
echo "    RabbitMQ & MQTT Automated Setup Script        "
echo "=================================================="

# 1. Collect inputs from the user
read -p "Enter RabbitMQ Admin Username (default: admin): " RABBIT_USER
RABBIT_USER=${RABBIT_USER:-admin}

read -s -p "Enter RabbitMQ Admin Password: " RABBIT_PASS
echo ""
if [ -z "$RABBIT_PASS" ]; then
    echo "Password cannot be empty!"
    exit 1
fi

read -p "Enter your Hostname or Domain Name (e.g., rabbitmq.yourdomain.com or server IP): " RABBIT_HOST
RABBIT_HOST=${RABBIT_HOST:-localhost}

echo "--------------------------------------------------"
echo "Configuration Summary:"
echo "  - Username: $RABBIT_USER"
echo "  - Host/Domain: $RABBIT_HOST"
echo "--------------------------------------------------"

# 2. Check if Docker is installed, install if needed
if ! command -v docker &> /dev/null; then
    echo "[+] Docker not found. Installing Docker..."
    if [ -f /etc/oracle-release ] || [ -f /etc/redhat-release ]; then
        # Oracle Linux / RHEL / CentOS workflow
        sudo yum install -y docker-engine || sudo dnf install -y docker
    elif [ -f /etc/debian_version ]; then
        # Ubuntu / Debian workflow
        sudo apt-get update
        sudo apt-get install -y docker.io
    else
        echo "[-] Unsupported Linux distribution. Please install Docker manually."
        exit 1
    fi
    echo "[+] Enabling and starting Docker service..."
    sudo systemctl enable --now docker
else
    echo "[+] Docker is already installed."
fi

# Ensure current user can run docker without sudo (optional, adds to docker group)
if ! groups $USER | grep &>/dev/null "\bdocker\b"; then
    echo "[+] Adding current user to the docker group..."
    sudo usermod -aG docker $USER
    echo "[!] Note: You may need to log out and back in for non-root docker commands to work. Continuing with sudo for this session..."
fi

# 3. Create Persistent Directory & Enabled Plugins File
RABBIT_DIR="$HOME/RabbitMQ"
echo "[+] Setting up configuration directory at $RABBIT_DIR..."
mkdir -p "$RABBIT_DIR"

echo "[+] Creating enabled_plugins file..."
cat << EOF > "$RABBIT_DIR/enabled_plugins"
[rabbitmq_management,rabbitmq_mqtt].
EOF

# Set required permissions for the volume mount
chmod 777 "$RABBIT_DIR/enabled_plugins"

# 4. Stop and remove any existing rabbitmq container if present
if [ "$(sudo docker ps -a -q -f name=rabbitmq)" ]; then
    echo "[+] Removing existing RabbitMQ container..."
    sudo docker rm -f rabbitmq
fi

# 5. Run the RabbitMQ Docker Container
echo "[+] Starting RabbitMQ container..."
sudo docker run -d \
    --restart always \
    --hostname "$RABBIT_HOST" \
    -p 80:15672 \
    -p 1883:1883 \
    -p 443:15671 \
    -e RABBITMQ_DEFAULT_USER="$RABBIT_USER" \
    -e RABBITMQ_DEFAULT_PASS="$RABBIT_PASS" \
    -v "$RABBIT_DIR/enabled_plugins:/etc/rabbitmq/enabled_plugins" \
    -v "$RABBIT_DIR:/var/lib/rabbitmq" \
    --name rabbitmq \
    rabbitmq:3-management

# 6. Wait for startup completion
echo "[+] Waiting for RabbitMQ to complete initialization..."
for i in {1..30}; do
    if sudo docker logs rabbitmq 2>&1 | grep -q "Server startup complete"; then
        echo "[+] RabbitMQ started successfully!"
        break
    fi
    sleep 2
done

# 7. Print summary, ingress rules, and dashboard URL
echo "=================================================="
echo "               SETUP COMPLETE                     "
echo "=================================================="
echo ""
echo "[!] IMPORTANT: Ensure you have set up Cloud/Server Ingress rules"
echo "    (Firewall / Security Lists) to allow inbound traffic on:"
echo "      - Port 80   (HTTP / Web Management UI)"
echo "      - Port 443  (HTTPS / Secure Web Management UI)"
echo "      - Port 1883 (MQTT Broker Traffic)"
echo ""
echo "Access your RabbitMQ Dashboard at:"
echo "  -> http://$RABBIT_HOST"
echo "  -> Username: $RABBIT_USER"
echo "=================================================="
