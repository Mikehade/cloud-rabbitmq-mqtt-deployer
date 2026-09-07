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
        sudo yum install -y docker-engine || sudo dnf install -y docker
    elif [ -f /etc/debian_version ]; then
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
chmod 777 "$RABBIT_DIR/enabled_plugins"
# 4. Stop and remove any existing rabbitmq container if present
if [ "$(sudo docker ps -a -q -f name=rabbitmq)" ]; then
    echo "[+] Removing existing RabbitMQ container..."
    sudo docker rm -f rabbitmq
fi
# 5. Detect port conflicts and choose Management UI port
MGMT_PORT=80
MGMT_PORT_INTERNAL=15672
if sudo ss -tlnp | grep -q ":80 "; then
    BLOCKING_PROCESS=$(sudo ss -tlnp | grep ":80 " | grep -oP 'users:\(\("\K[^"]+' | head -1)
    echo ""
    echo "[!] WARNING: Port 80 is already in use by: ${BLOCKING_PROCESS:-unknown process}"
    echo "    This is likely nginx or Apache acting as a reverse proxy or web server."
    echo "    Stopping it could break other services running on this machine."
    echo ""
    echo "    --> Falling back to port 15672 for the RabbitMQ Management UI."
    echo ""
    MGMT_PORT=15672
fi
# 6. Run the RabbitMQ Docker Container
echo "[+] Starting RabbitMQ container..."
# Temporarily disable exit-on-error to handle docker failure gracefully
set +e
sudo docker run -d \
    --restart always \
    --hostname "$RABBIT_HOST" \
    -p "$MGMT_PORT:$MGMT_PORT_INTERNAL" \
    -p 1883:1883 \
    -p 443:15671 \
    -e RABBITMQ_DEFAULT_USER="$RABBIT_USER" \
    -e RABBITMQ_DEFAULT_PASS="$RABBIT_PASS" \
    -v "$RABBIT_DIR/enabled_plugins:/etc/rabbitmq/enabled_plugins" \
    -v "$RABBIT_DIR:/var/lib/rabbitmq" \
    --name rabbitmq \
    rabbitmq:3-management
DOCKER_EXIT=$?
set -e
# 7. If docker run still failed (e.g. port 443 conflict), report clearly
if [ $DOCKER_EXIT -ne 0 ]; then
    echo ""
    echo "[-] ERROR: Docker failed to start the RabbitMQ container."
    echo "    This may be due to another port conflict (e.g. 443 or 1883)."
    echo "    Run the following to investigate:"
    echo "      sudo ss -tlnp | grep -E ':443|:1883'"
    echo ""
    exit 1
fi
# 8. Wait for startup completion
echo "[+] Waiting for RabbitMQ to complete initialization..."
for i in {1..30}; do
    if sudo docker logs rabbitmq 2>&1 | grep -q "Server startup complete"; then
        echo "[+] RabbitMQ started successfully!"
        break
    fi
    sleep 2
done
# 9. Print summary
echo ""
echo "=================================================="
echo "               SETUP COMPLETE                     "
echo "=================================================="
echo ""
echo "[!] IMPORTANT: Ensure you have set up Cloud/Server Ingress rules"
echo "    (Firewall / Security Lists) to allow inbound traffic on:"
if [ "$MGMT_PORT" -eq 15672 ]; then
    echo "      - Port 15672 (RabbitMQ Management UI — fallback, port 80 was taken)"
else
    echo "      - Port 80    (HTTP / Web Management UI)"
fi
echo "      - Port 443  (HTTPS / Secure Web Management UI)"
echo "      - Port 1883 (MQTT Broker Traffic)"
echo ""
echo "Access your RabbitMQ Dashboard at:"
if [ "$MGMT_PORT" -eq 15672 ]; then
    echo "  -> http://$RABBIT_HOST:15672"
    echo "     (Port 80 was in use — open port 15672 in your firewall/security group)"
else
    echo "  -> http://$RABBIT_HOST"
fi
echo "  -> Username: $RABBIT_USER"
echo "=================================================="
