FROM debian:bookworm-slim AS base

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install base system utilities
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    wget \
    git \
    vim \
    nano \
    net-tools \
    iputils-ping \
    ca-certificates \
    apt-transport-https \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-setuptools \
    supervisor \
    bash-completion \
    jq \
    openssh-client \
    procps \
    zip \
    unzip \
    --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install XFCE desktop environment
RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-terminal \
    mousepad \
    xfce4-taskmanager \
    xvfb \
    --no-install-recommends \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install remote desktop tools
RUN apt-get update && apt-get install -y \
    firefox-esr \
    xrdp \
    dbus-x11 \
    xterm \
    --no-install-recommends \
    && apt-get install -y tigervnc-standalone-server 2>/dev/null || apt-get install -y tigervnc-server || apt-get install -y tigervnc-common \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install yq
RUN curl -L -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq

# Install noVNC for web access
RUN mkdir -p /opt/novnc \
    && curl -L -o /tmp/novnc.tar.gz https://github.com/novnc/noVNC/archive/v1.4.0.tar.gz \
    && tar -xzf /tmp/novnc.tar.gz --strip-components=1 -C /opt/novnc \
    && rm /tmp/novnc.tar.gz \
    && curl -L -o /tmp/websockify.tar.gz https://github.com/novnc/websockify/archive/v0.11.0.tar.gz \
    && mkdir -p /opt/novnc/utils/websockify \
    && tar -xzf /tmp/websockify.tar.gz --strip-components=1 -C /opt/novnc/utils/websockify \
    && rm /tmp/websockify.tar.gz

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    && rm get_helm.sh

# Install k9s
RUN curl -L -o k9s.tar.gz "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz" \
    && tar -xzf k9s.tar.gz -C /tmp \
    && mv /tmp/k9s /usr/local/bin/ \
    && rm k9s.tar.gz

# Install Terraform directly from released binary
RUN curl -fsSL -o terraform.zip https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip \
    && unzip terraform.zip \
    && install -o root -g root -m 0755 terraform /usr/local/bin/terraform \
    && rm terraform.zip

# Install kubectx and kubens directly
RUN curl -L -o /usr/local/bin/kubectx https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx \
    && curl -L -o /usr/local/bin/kubens https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens \
    && chmod +x /usr/local/bin/kubectx /usr/local/bin/kubens

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli \
    && rm -rf aws awscliv2.zip

# Install Google Cloud SDK
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    apt-get update && apt-get install -y google-cloud-sdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Instead of Azure CLI, install az CLI via script without prompts
RUN apt-get update && \
    apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash > /dev/null && \
    # Disable data collection
    az config set core.collect_telemetry=false --only-show-errors && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set up VNC server
RUN mkdir -p /root/.vnc
COPY vnc-config/xstartup /root/.vnc/xstartup
RUN chmod +x /root/.vnc/xstartup \
    && echo "password" | vncpasswd -f > /root/.vnc/passwd \
    && chmod 600 /root/.vnc/passwd

# Create a non-root user
RUN useradd -m -s /bin/bash clouduser \
    && echo "clouduser:password" | chpasswd \
    && usermod -aG sudo clouduser \
    && mkdir -p /home/clouduser/.vnc \
    && cp /root/.vnc/xstartup /home/clouduser/.vnc/ \
    && echo "password" | vncpasswd -f > /home/clouduser/.vnc/passwd \
    && chmod 600 /home/clouduser/.vnc/passwd \
    && chown -R clouduser:clouduser /home/clouduser/.vnc

# Set up the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
EXPOSE 5901 3389 6080

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Final stage
FROM base AS final
COPY --from=0 / /
ENTRYPOINT ["/entrypoint.sh"]