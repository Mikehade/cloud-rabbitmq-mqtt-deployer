# RabbitMQ & MQTT Cloud Deployer

A production-ready, interactive automation script to instantly provision and configure **RabbitMQ** (with native **MQTT** and **Management plugins** enabled) on any Linux instance using Docker. 

Designed specifically for IoT messaging architectures, lightweight pub/sub pipelines, and cloud instances (such as Oracle Cloud Always Free tiers, AWS EC2, or DigitalOcean Droplets).

---

## Features

- **Automated Docker Provisioning:** Checks if Docker is installed on the target Linux system (`yum`, `dnf`, or `apt` based distros) and installs/starts it automatically if missing.
- **Interactive Configuration:** Prompts securely for your custom admin credentials and server domain/hostname.
- **Persistent Storage & Plugins:** Automatically configures persistent volume mounts for database state and pre-enables the `rabbitmq_management` and `rabbitmq_mqtt` plugins.
- **Production-Ready Ports:** Maps standard external web ports (`80` and `443`) and MQTT protocol ports (`1883`) straight out of the box.
- **Health Check & Summary:** Monitors container logs until startup completion and outputs exact firewall/ingress requirements and dashboard endpoints.

---

## Prerequisites

- A Linux virtual machine (Ubuntu, Debian, Oracle Linux, RHEL, or CentOS).
- Sudo/root privileges on the target machine.
- DNS configured to point your domain/subdomain to your server's public IP address (recommended for the web management UI).

---

## Quick Start

Run the setup script directly on your remote server via `curl`:

```bash
curl -sO https://raw.githubusercontent.com/Mikehade/cloud-rabbitmq-mqtt-deployer/main/setup-rabbitmq.sh
chmod +x setup-rabbitmq.sh
./setup-rabbitmq.sh

```

Alternatively, clone the repository and run it locally:

```bash
git clone https://github.com/Mikehade/cloud-rabbitmq-mqtt-deployer.git
cd cloud-rabbitmq-mqtt-deployer
chmod +x setup-rabbitmq.sh
./setup-rabbitmq.sh

```

---

## Interactive Prompts

During execution, the script will request:

1. **Admin Username:** (Defaults to `admin` if left blank).
2. **Admin Password:** (Securely hidden input).
3. **Hostname / Domain:** (e.g., `rabbitmq.yourdomain.com` or your server's public IP).

---

## Required Firewall & Ingress Rules

To access the web UI and accept external IoT/MQTT traffic, ensure your cloud provider's Security List or firewall allows inbound traffic on the following ports:

| Port | Protocol | Purpose |
| --- | --- | --- |
| **80** | TCP | HTTP Traffic (Mapped to RabbitMQ Management UI) |
| **443** | TCP | HTTPS Traffic (Secure Management UI / SSL) |
| **1883** | TCP | MQTT Broker Traffic (For IoT devices, Arduino, etc.) |

---

## Testing Your Installation

Once the script completes, you can verify your MQTT pipeline using standard command-line tools like `mosquitto`:

### 1. Subscribe to a Topic

```bash
mosquitto_sub -h YOUR_SERVER_IP -p 1883 -u YOUR_USERNAME -P YOUR_PASSWORD -t "demo/topic"

```

### 2. Publish a Test Message

```bash
mosquitto_pub -h YOUR_SERVER_IP -p 1883 -u YOUR_USERNAME -P YOUR_PASSWORD -t "demo/topic" -m "Hello from IoT device!"

```

---

## Management Dashboard

Open your browser and navigate to:

```text
http://YOUR_SERVER_IP (or [http://your-domain.com](http://your-domain.com))

```

Log in using the username and password you provided during the script setup.

---

