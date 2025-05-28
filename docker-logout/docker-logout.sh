#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step "Starting Docker logout process..."

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not available in PATH"
    exit 1
fi

# Determine registry to logout from
REGISTRY=""
REGISTRY_NAME="Docker Hub"

# Priority order: explicit input > environment variable > default
if [ -n "$INPUT_REGISTRY" ]; then
    REGISTRY="$INPUT_REGISTRY"
    REGISTRY_NAME="$REGISTRY"
elif [ -n "$DOCKER_REGISTRY_TO_LOGOUT" ]; then
    REGISTRY="$DOCKER_REGISTRY_TO_LOGOUT"
    if [ -n "$REGISTRY" ]; then
        REGISTRY_NAME="$REGISTRY"
    fi
fi

print_info "Target registry: $REGISTRY_NAME"

# Perform logout
print_step "Logging out from Docker registry..."

if [ -n "$REGISTRY" ]; then
    if docker logout "$REGISTRY"; then
        print_info "✅ Successfully logged out from $REGISTRY_NAME"
    else
        print_error "❌ Failed to logout from $REGISTRY_NAME"
        exit 1
    fi
else
    if docker logout; then
        print_info "✅ Successfully logged out from Docker Hub"
    else
        print_error "❌ Failed to logout from Docker Hub"
        exit 1
    fi
fi

# Clean up environment variables
if [ "$DOCKER_LOGOUT_ENABLED" = "true" ]; then
    echo "DOCKER_LOGOUT_ENABLED=false" >> $GITHUB_ENV
    echo "DOCKER_REGISTRY_TO_LOGOUT=" >> $GITHUB_ENV
fi

print_info "🎉 Docker logout completed successfully!"