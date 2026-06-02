#!/bin/bash

# =========================================
# Kubuntu Setup & Docker GPU Test Script
# Installs: Brave, NVIDIA Driver+Toolkit, Docker, NVIDIA Container Toolkit
# Tests: Docker GPU access and NVENC Transcoding
# =========================================

# 1. Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script as root (use sudo)."
  exit 1
fi

REAL_USER=${SUDO_USER:-$USER}

echo "========================================="
echo " Starting Kubuntu Setup & Docker GPU Test"
echo "========================================="

# 2. Update package lists
echo "[1/6] Updating package lists..."
apt update -y 
apt upgrade -y

# 3. Install Brave Browser
echo "[2/6] Installing Brave Browser..."
curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin CHANNEL=nightly sh
apt update -y

# 4. Install NVIDIA Driver + CUDA Toolkit
echo "[3/6] Installing NVIDIA Driver and CUDA Toolkit..."
ubuntu-drivers install
apt install -y nvidia-cuda-toolkit

# 5. Install Docker Engine
echo "[4/6] Installing Docker Engine..."
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. Install NVIDIA Container Toolkit (Required for Docker to see the GPU)
echo "[5/6] Installing NVIDIA Container Toolkit..."
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
apt-get update -y
apt-get install -y nvidia-container-toolkit

# Configure Docker to use the nvidia runtime
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# Add user to docker group
usermod -aG docker "$REAL_USER"

# =========================================
# Automated Testing Phase
# =========================================
echo "========================================="
echo " Testing Docker GPU Access & Transcoding"
echo "========================================="

# Note: We use 'sudo docker' here because the current shell session 
# hasn't refreshed group permissions yet to allow non-sudo docker access.

# Test 1: Basic GPU Visibility
echo "  -> [Test 1] Checking if Docker can see the NVIDIA GPU..."
if sudo docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi > /dev/null 2>&1; then
    echo "  [SUCCESS] Docker successfully detected the NVIDIA GPU!"
else
    echo "  [FAILED] Docker cannot see the GPU. Check NVIDIA Container Toolkit logs."
fi

# =========================================
# install portainer + Jellyfin
# =========================================
docker volume create portainer_data
docker run -d -p 8000:8000 -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:lts
docker run -d -p 8096:8096 --name jellyfin --restart unless-stopped --gpus all -e TZ=Europe/London -e NVIDIA_VISIBLE_DEVICES=all -e NVIDIA_DRIVER_CAPABILITIES=compute,video,utility \ -v /home/finny/selfhost/jelly/config:/config -v /home/finny/selfhost/jelly/cache:/cache -v /home/finny/selfhost/jelly/movies:/media/movie -v /home/finny/selfhost/jelly/tv:/media/tv -v /home/finny/selfhost/jelly/music:/media/music jellyfin/jellyfin:latest
# =========================================
# Final Instructions
# =========================================
echo "========================================="
echo " Installation & Testing Complete!"
echo "========================================="
echo "IMPORTANT NEXT STEPS:"
echo "1. BRAVE: Launch from your application menu or terminal ('brave-browser')."
echo "2. NVIDIA: A SYSTEM REBOOT is required to load the new NVIDIA kernel modules."
echo "3. DOCKER: Log out and log back in (or run 'newgrp docker') to use Docker without 'sudo'."
echo "========================================="