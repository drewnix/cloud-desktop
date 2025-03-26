#!/bin/bash
set -e

# Set default values for environment variables
VNC_GEOMETRY=${VNC_GEOMETRY:-1280x800}
VNC_DEPTH=${VNC_DEPTH:-24}

echo "Configuring VNC with geometry $VNC_GEOMETRY and depth $VNC_DEPTH"

# Create default .Xresources file if it doesn't exist to avoid VNC errors
function setup_vnc_env() {
  if [ ! -f "$HOME/.Xresources" ]; then
    touch "$HOME/.Xresources"
  fi
  if [ ! -d "$HOME/.vnc" ]; then
    mkdir -p "$HOME/.vnc"
  fi
}

# Run as clouduser if root
if [ "$(id -u)" = "0" ]; then
  echo "Running as root - switching to clouduser for VNC session"
  # Create necessary files for clouduser
  if [ ! -f "/home/clouduser/.Xresources" ]; then
    touch /home/clouduser/.Xresources
    chown clouduser:clouduser /home/clouduser/.Xresources
  fi
  # Make sure XFCE is installed before starting vnc server
  if [ -x "$(command -v startxfce4)" ]; then
    su - clouduser -c "vncserver :1 -geometry $VNC_GEOMETRY -depth $VNC_DEPTH -localhost no"
  else
    echo "XFCE not found, starting VNC with basic X session"
    su - clouduser -c "vncserver :1 -geometry $VNC_GEOMETRY -depth $VNC_DEPTH -localhost no -xstartup /usr/bin/xterm"
  fi
else
  # Create necessary files for the current user
  setup_vnc_env
  # Start VNC server with the current user
  if [ -x "$(command -v startxfce4)" ]; then
    vncserver :1 -geometry $VNC_GEOMETRY -depth $VNC_DEPTH -localhost no
  else
    echo "XFCE not found, starting VNC with basic X session"
    vncserver :1 -geometry $VNC_GEOMETRY -depth $VNC_DEPTH -localhost no -xstartup /usr/bin/xterm
  fi
fi

# Start xrdp (must be run as root)
if [ "$(id -u)" = "0" ]; then
  /etc/init.d/xrdp start
else
  sudo /etc/init.d/xrdp start
fi

# Start noVNC
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 6080 &

# Set up bashrc additions if not already configured
CLOUD_BASHRC_CONFIG=$(cat <<EOF
# Cloud Desktop custom configuration
alias k=kubectl
source <(kubectl completion bash)
complete -F __start_kubectl k
source /etc/bash_completion
EOF
)

# Add cloud desktop config to bashrc for both root and clouduser
if ! grep -q "Cloud Desktop custom configuration" /root/.bashrc; then
  echo "${CLOUD_BASHRC_CONFIG}" >> /root/.bashrc
fi

if ! grep -q "Cloud Desktop custom configuration" /home/clouduser/.bashrc; then
  echo "${CLOUD_BASHRC_CONFIG}" >> /home/clouduser/.bashrc
  chown clouduser:clouduser /home/clouduser/.bashrc
fi

echo "========================================"
echo "Cloud Desktop is running!"
echo "Connect using:"
echo "  VNC: hostname:5901"
echo "  RDP: hostname:3389"
echo "  Web: http://hostname:6080/vnc.html"
echo "========================================"

# Keep the container running
tail -f /dev/null