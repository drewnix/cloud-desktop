#!/bin/bash
set -e

# Set default values for environment variables
VNC_GEOMETRY=${VNC_GEOMETRY:-1280x800}
VNC_DEPTH=${VNC_DEPTH:-24}

echo "Configuring VNC with geometry $VNC_GEOMETRY and depth $VNC_DEPTH"

# Prepare XFCE environment
prepare_xfce() {
  # Create basic xfce config
  mkdir -p "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
  cat > "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/xfce/xfce-blue.jpg"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

  # Create a startup script for XFCE
  echo "#!/bin/bash" > "$HOME/.vnc/xstartup"
  echo "[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources" >> "$HOME/.vnc/xstartup"
  echo "startxfce4 &" >> "$HOME/.vnc/xstartup"
  chmod +x "$HOME/.vnc/xstartup"
}

# Create a basic xterm-only startup script
prepare_xterm() {
  echo "#!/bin/bash" > "$HOME/.vnc/xstartup"
  echo "[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources" >> "$HOME/.vnc/xstartup"
  echo "xterm &" >> "$HOME/.vnc/xstartup"
  chmod +x "$HOME/.vnc/xstartup"
}

# Setup VNC environment
setup_vnc_env() {
  # Create necessary dirs and files
  mkdir -p "$HOME/.vnc"
  touch "$HOME/.Xauthority"
  touch "$HOME/.Xresources"
  
  # Choose setup based on available desktop environment
  if [ -x "$(command -v startxfce4)" ]; then
    prepare_xfce
  else
    prepare_xterm
  fi
}

# Run as clouduser if root
if [ "$(id -u)" = "0" ]; then
  echo "Running as root - switching to clouduser for VNC session"
  
  # Setup environment for clouduser
  mkdir -p /home/clouduser/.vnc
  touch /home/clouduser/.Xauthority
  touch /home/clouduser/.Xresources
  
  if [ -x "$(command -v startxfce4)" ]; then
    # Setup XFCE for clouduser
    mkdir -p /home/clouduser/.config/xfce4/xfconf/xfce-perchannel-xml
    cat > /home/clouduser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="/usr/share/backgrounds/xfce/xfce-blue.jpg"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF
    
    # Create a startup script for XFCE
    echo "#!/bin/bash" > /home/clouduser/.vnc/xstartup
    echo "[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources" >> /home/clouduser/.vnc/xstartup
    echo "startxfce4 &" >> /home/clouduser/.vnc/xstartup
  else
    # Create a basic xterm-only startup script
    echo "#!/bin/bash" > /home/clouduser/.vnc/xstartup
    echo "[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources" >> /home/clouduser/.vnc/xstartup
    echo "xterm &" >> /home/clouduser/.vnc/xstartup
  fi
  
  # Ensure correct permissions
  chmod +x /home/clouduser/.vnc/xstartup
  chown -R clouduser:clouduser /home/clouduser/.vnc
  chown clouduser:clouduser /home/clouduser/.Xauthority /home/clouduser/.Xresources
  [ -d /home/clouduser/.config ] && chown -R clouduser:clouduser /home/clouduser/.config
  
  # Start VNC server
  if command -v xterm >/dev/null 2>&1; then
    # First try with a simple xterm as a fallback
    su - clouduser -c "DISPLAY=:1 vncserver :1 -geometry $VNC_GEOMETRY -depth $VNC_DEPTH -localhost no -xstartup /usr/bin/xterm"
  else
    # Fallback to a very basic session if even xterm is not available
    su - clouduser -c "DISPLAY=:1 vncserver :1 -geometry $VNC_GEOMETRY -depth $VNC_DEPTH -localhost no"
  fi
else
  # Setup environment for the current user
  setup_vnc_env
  
  # Start VNC server with the current user
  vncserver :1 -geometry $VNC_GEOMETRY -depth $VNC_DEPTH -localhost no
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

# Create a healthcheck file
if [ "$(id -u)" = "0" ]; then
  touch /tmp/healthy
  chmod 777 /tmp/healthy
  
  # Add a healthcheck script
  cat > /usr/local/bin/healthcheck.sh << 'EOF'
#!/bin/bash
# Check if VNC is running
if ! pgrep -f Xtigervnc > /dev/null; then
  echo "VNC server is not running!"
  exit 1
fi

# Check if noVNC is running
if ! pgrep -f novnc_proxy > /dev/null; then
  echo "noVNC proxy is not running!"
  exit 1
fi

# Check if XRDP is running
if ! ps aux | grep xrdp | grep -v grep > /dev/null; then
  echo "XRDP is not running!"
  exit 1
fi

# All services are running
touch /tmp/healthy
echo "All services are running"
exit 0
EOF
  chmod +x /usr/local/bin/healthcheck.sh
  
  # Run healthcheck periodically
  (while true; do /usr/local/bin/healthcheck.sh; sleep 30; done) &
fi

# Keep the container running
echo "Cloud Desktop is now running! Press Ctrl+C to stop."
trap 'echo "Shutting down..."; exit 0' TERM INT
while true; do
  sleep 1
  # Exit if VNC server dies
  if [ "$(id -u)" = "0" ]; then
    if ! pgrep -f Xtigervnc > /dev/null; then
      echo "VNC server has stopped, shutting down container..."
      exit 1
    fi
  fi
done