#!/bin/bash
# Simple test script for cloud-desktop container
set -e

CONTAINER_NAME="cloud-desktop-test"
IMAGE_NAME="cloud-desktop:latest-slim"

# Clean up any previous test containers
echo "Cleaning up any previous test containers..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Start the container
echo "Starting test container..."
docker run -d \
  --name $CONTAINER_NAME \
  -p 5901:5901 \
  -p 3389:3389 \
  -p 6080:6080 \
  $IMAGE_NAME

# Wait for container to initialize
echo "Waiting for services to start up..."
sleep 30 # Give more time for services to initialize

# Show logs to help debug
echo "Container logs:"
docker logs $CONTAINER_NAME

# Check if the container is still running
echo "Testing container health..."
if docker ps | grep $CONTAINER_NAME; then
  echo "✓ Container is running - test passed!"
else
  echo "✗ Container stopped unexpectedly"
  exit 1
fi

# Check if VNC port is accessible
echo "Testing VNC port..."
if nc -z localhost 5901; then
  echo "✓ VNC port is accessible"
else
  echo "✗ VNC port is not accessible"
fi

# Check if RDP port is accessible
echo "Testing RDP port..."
if nc -z localhost 3389; then
  echo "✓ RDP port is accessible"
else
  echo "✗ RDP port is not accessible"
fi

# Check if noVNC port is accessible
echo "Testing noVNC port..."
if nc -z localhost 6080; then
  echo "✓ noVNC port is accessible"
else
  echo "✗ noVNC port is not accessible"
fi

# Clean up
echo "All tests completed! Cleaning up..."
docker stop $CONTAINER_NAME
docker rm $CONTAINER_NAME