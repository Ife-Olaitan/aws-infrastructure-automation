#!/bin/bash
set -e

# Log output for debugging
exec > >(tee /var/log/user-data.log) 2>&1

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add user to docker group
usermod -aG docker ubuntu

# Create application directory
mkdir -p /opt/app
chown ubuntu:ubuntu /opt/app

# Enable Docker service
systemctl enable docker
systemctl start docker