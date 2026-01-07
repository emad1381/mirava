#!/usr/bin/env bash
# Quick Fix: نصب yq binary و اجرای اسکریپت چک میرورها

echo "🔧 Uninstalling Python yq..."
pip3 uninstall yq -y 2>/dev/null

echo "📥 Installing yq binary..."
VERSION=v4.44.1
BINARY=yq_linux_amd64

cd /tmp
wget -q https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O yq
chmod +x yq
sudo mv yq /usr/local/bin/yq

echo "✅ yq installed successfully!"
yq --version

echo ""
echo "🚀 Running mirror check script..."
cd ~/mirava
./check_mirrors.sh
