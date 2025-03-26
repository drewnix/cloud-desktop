# Cloud Desktop

A containerized remote desktop environment designed to serve as a jump system for managing cloud infrastructure and Kubernetes clusters.

## Features

- XFCE desktop environment accessible via VNC, RDP, or web browser
- Pre-installed cloud management tools:
  - Kubernetes: kubectl, helm, k9s, kubectx/kubens
  - IaC: Terraform
  - Cloud Provider CLIs: AWS, GCP, Azure
  - Development tools: git, curl, vim, jq, etc.
- Persistent storage for user data
- Kubernetes-ready deployment

## Quick Start

### Building the Container

```bash
# Clone the repository
git clone https://github.com/yourusername/cloud-desktop.git
cd cloud-desktop

# Build the full container (this may take some time due to dependencies)
make build

# Or build a minimal version for testing
make build-slim
```

### Running Locally

```bash
# Using Makefile (recommended)
make run-detached

# Or with Docker directly
docker run -d \
  --name cloud-desktop \
  -p 5901:5901 \
  -p 3389:3389 \
  -p 6080:6080 \
  cloud-desktop:latest

# For testing with minimal version
make run-slim

# Access via VNC client
# VNC address: localhost:5901
# Password: password

# Access via RDP client
# RDP address: localhost:3389
# Username: clouduser
# Password: password

# Access via web browser
# URL: http://localhost:6080/vnc.html
# Password: password
```

### Deploying to Kubernetes

```bash
# Using Makefile (recommended)
make deploy-k8s

# Or manually
kubectl apply -f manifests/cloud-desktop.yaml

# Access the service (depends on your Kubernetes setup)
# For Ingress access: https://cloud-desktop.example.com
```

## Configuration

### Environment Variables

The container supports the following environment variables:

- `VNC_GEOMETRY`: Set VNC screen resolution (default: 1280x800)
- `VNC_DEPTH`: Set VNC color depth (default: 24)

### Persistent Storage

User data is stored in `/home/clouduser` which can be mounted as a volume for persistence.

## Security Notes

- Default passwords are set for demonstration purposes only
- For production use, configure proper authentication mechanisms
- Consider implementing TLS for all connections

## Development

See [DESIGN.md](DESIGN.md) for technical design details and [ROADMAP.md](ROADMAP.md) for the development roadmap.