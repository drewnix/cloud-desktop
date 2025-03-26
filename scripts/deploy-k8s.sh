#!/bin/bash
# Script to deploy cloud-desktop to Kubernetes
set -e

# Default values
NAMESPACE=${K8S_NAMESPACE:-"cloud-desktop"}
REGISTRY=${REGISTRY:-""}
IMAGE_NAME=${IMAGE_NAME:-"cloud-desktop"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --namespace) NAMESPACE="$2"; shift ;;
    --registry) REGISTRY="$2"; shift ;;
    --tag) IMAGE_TAG="$2"; shift ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Construct image name
if [ -n "$REGISTRY" ]; then
  FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
else
  FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
fi

echo "Deploying cloud-desktop to Kubernetes"
echo "Namespace: $NAMESPACE"
echo "Image: $FULL_IMAGE_NAME"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Update the deployment manifest with the correct image
TMP_MANIFEST=$(mktemp)
sed "s|image: cloud-desktop:latest|image: ${FULL_IMAGE_NAME}|g" manifests/cloud-desktop.yaml > "$TMP_MANIFEST"

# Apply the manifest
kubectl apply -f "$TMP_MANIFEST" -n "$NAMESPACE"

# Clean up
rm "$TMP_MANIFEST"

echo "Deployment complete!"
echo "Check status with: kubectl get all -n $NAMESPACE"
echo "Access noVNC web interface via configured Ingress or port-forward with:"
echo "kubectl port-forward -n $NAMESPACE svc/cloud-desktop 6080:6080"