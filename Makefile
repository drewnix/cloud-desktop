# Cloud Desktop Makefile
# Provides commands for building, testing, and deploying the cloud desktop container

# Variables
IMAGE_NAME := cloud-desktop
IMAGE_TAG := latest
FULL_IMAGE_NAME := $(IMAGE_NAME):$(IMAGE_TAG)
CONTAINER_NAME := cloud-desktop

# Default registry is left empty - can be overridden with environment variables
REGISTRY ?= 
REGISTRY_PREFIX := $(if $(REGISTRY),$(REGISTRY)/,)

# Kubernetes namespace
K8S_NAMESPACE ?= cloud-desktop

.PHONY: help build build-verbose build-slim build-base run run-slim run-detached stop clean test deploy-k8s delete-k8s push

help:
	@echo "Cloud Desktop - Containerized remote desktop for cloud infrastructure management"
	@echo ""
	@echo "Usage:"
	@echo "  make build            - Build the Docker image"
	@echo "  make build-base       - Build only the base image (useful for debugging)"
	@echo "  make build-verbose    - Build the Docker image with verbose output"
	@echo "  make build-slim       - Build a minimal version of the image (for debugging)"
	@echo "  make run              - Run the container locally"
	@echo "  make run-slim         - Run the slim version of the container"
	@echo "  make run-detached     - Run the container in detached mode"
	@echo "  make stop             - Stop and remove the running container"
	@echo "  make clean            - Remove the Docker image"
	@echo "  make test             - Run tests on the container"
	@echo "  make deploy-k8s       - Deploy to Kubernetes"
	@echo "  make delete-k8s       - Delete from Kubernetes"
	@echo "  make push             - Push image to registry"
	@echo ""
	@echo "Environment Variables:"
	@echo "  REGISTRY              - Docker registry to push to (e.g., gcr.io/my-project)"
	@echo "  IMAGE_TAG             - Tag for the Docker image (default: latest)"
	@echo "  K8S_NAMESPACE         - Kubernetes namespace to deploy to (default: cloud-desktop)"

build-base:
	@echo "Building base image $(FULL_IMAGE_NAME)-base..."
	docker build --progress=plain --no-cache --target base -t $(FULL_IMAGE_NAME)-base .

build:
	@echo "Building $(FULL_IMAGE_NAME)..."
	docker build --progress=plain --no-cache -t $(FULL_IMAGE_NAME) .

build-verbose:
	@echo "Building $(FULL_IMAGE_NAME) with verbose output..."
	docker build --progress=plain -t $(FULL_IMAGE_NAME) .
	
build-slim:
	@echo "Building slim version $(FULL_IMAGE_NAME)-slim..."
	docker build --progress=plain -f Dockerfile.slim -t $(FULL_IMAGE_NAME)-slim .

run:
	@echo "Running $(FULL_IMAGE_NAME) interactively..."
	docker run --rm -it \
		--name $(CONTAINER_NAME) \
		-p 5901:5901 \
		-p 3389:3389 \
		-p 6080:6080 \
		$(FULL_IMAGE_NAME)
		
run-slim:
	@echo "Running $(FULL_IMAGE_NAME)-slim interactively..."
	docker run --rm -it \
		--name $(CONTAINER_NAME)-slim \
		$(FULL_IMAGE_NAME)-slim

run-detached:
	@echo "Running $(FULL_IMAGE_NAME) in detached mode..."
	docker run -d \
		--name $(CONTAINER_NAME) \
		-p 5901:5901 \
		-p 3389:3389 \
		-p 6080:6080 \
		--restart unless-stopped \
		$(FULL_IMAGE_NAME)
	@echo "Container started. Access via:"
	@echo "  - VNC: localhost:5901"
	@echo "  - RDP: localhost:3389"
	@echo "  - Web: http://localhost:6080/vnc.html"
	@echo "Container logs can be viewed with: docker logs $(CONTAINER_NAME)"

stop:
	@echo "Stopping container $(CONTAINER_NAME)..."
	-docker stop $(CONTAINER_NAME)
	-docker rm $(CONTAINER_NAME)

clean: stop
	@echo "Removing image $(FULL_IMAGE_NAME)..."
	-docker rmi $(FULL_IMAGE_NAME)

# Run the test script
test: build
	@echo "Testing container $(FULL_IMAGE_NAME)..."
	./scripts/test.sh

# Push image to registry if specified
push:
	@if [ -z "$(REGISTRY)" ]; then \
		echo "Error: REGISTRY not specified. Example: make push REGISTRY=gcr.io/my-project"; \
		exit 1; \
	fi
	@echo "Tagging image for registry $(REGISTRY)..."
	docker tag $(FULL_IMAGE_NAME) $(REGISTRY_PREFIX)$(FULL_IMAGE_NAME)
	@echo "Pushing image to registry..."
	docker push $(REGISTRY_PREFIX)$(FULL_IMAGE_NAME)

# Kubernetes deployment
deploy-k8s: build
	@echo "Deploying to Kubernetes in namespace $(K8S_NAMESPACE)..."
	./scripts/deploy-k8s.sh --namespace $(K8S_NAMESPACE) $(if $(REGISTRY),--registry $(REGISTRY),) --tag $(IMAGE_TAG)

delete-k8s:
	@echo "Deleting Cloud Desktop from Kubernetes namespace $(K8S_NAMESPACE)..."
	kubectl delete -f manifests/cloud-desktop.yaml -n $(K8S_NAMESPACE)