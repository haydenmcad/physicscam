#!/bin/bash
set -e

echo "=================================="
echo "Pi Camera Auto Installer"
echo "=================================="

# Must run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo or as root"
  exit 1
fi

echo "[1/6] Updating system..."
apt update && apt upgrade -y

echo "[2/6] Installing dependencies..."
apt install -y \
python3-opencv \
nginx \
lsof \
gstreamer1.0-tools \
gstreamer1.0-plugins-good \
gstreamer1.0-plugins-bad \
gstreamer1.0-plugins-ugly \
gstreamer1.0-libav

echo "[2.5/6] Configuring Wi-Fi (School Router)..."

apt install -y network-manager
systemctl enable NetworkManager
systemctl start NetworkManager

sleep 3

nmcli dev wifi connect "NETGEAR47"

echo "Wi-Fi configured and saved permanently"

echo "[3/6] Setting up camera app..."
mkdir -p /opt/pi-cam
cp stream.py /opt/pi-cam/stream.py

echo "[4/6] Creating systemd service..."
cat > /etc/systemd/system/pi-cam.service <<EOF
[Unit]
Description=Pi Camera Stream
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/pi-cam/stream.py
WorkingDirectory=/opt/pi-cam
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pi-cam.service

echo "[5/6] Configuring Nginx reverse proxy..."
cat > /etc/nginx/sites-available/pi-cam <<EOF
server {
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:8080;

        proxy_buffering off;
        proxy_cache off;
        gzip off;

        add_header Cache-Control no-cache;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/pi-cam /etc/nginx/sites-enabled/pi-cam

systemctl restart nginx

echo "[6/6] Finalizing installation..."


echo "=================================="
echo "SETUP COMPLETE"
echo "=================================="
echo ""
echo ""
echo "Stream will be available on your local network at:"
echo "http://<pi-ip>/"
echo "=================================="

systemctl start pi-cam.service
