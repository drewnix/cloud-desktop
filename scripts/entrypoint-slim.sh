#!/bin/bash
set -e

echo "========================================"
echo "Cloud Desktop (Slim) is running!"
echo "This is a minimal version with basic cloud tools"
echo "========================================"

# Keep the container running 
echo "Cloud Desktop (Slim) is now running! Press Ctrl+C to stop."
trap 'echo "Shutting down..."; exit 0' TERM INT
while true; do
  sleep 1
done