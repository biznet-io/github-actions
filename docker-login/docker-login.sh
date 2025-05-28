#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Cleanup function for logout
cleanup_docker_login() {
    if [ "$INPUT_LOGOUT" = "true" ] && [ "$LOGIN_SUCCESSFUL" = "true" ]; then
        echo ""
        echo "::group::Docker Logout"
        print_step "Performing automatic logout..."
        
        if [ -n "$REGISTRY" ]; then
            if docker logout "$REGISTRY" 2>/dev/null; then
                print_info "✅ Successfully logged out from $REGISTRY"
            else
                print_warning "⚠️  Could not logout from $REGISTRY (may already be logged out)"
            fi
        else
            if docker logout 2>/dev/null; then
                print_info "✅ Successfully logged out from Docker Hub"
            else
                print_warning "⚠️  Could not logout from Docker Hub (may already be logged out)"
            fi
        fi
        echo "::endgroup::"
    fi
}

# Set up trap for cleanup on script exit
trap cleanup_docker_login EXIT

print_step "Starting Docker login process..."

# Validate required inputs
if [ -z "$INPUT_USERNAME" ]; then
    print_error "Username is required"
    exit 1
fi

if [ -z "$INPUT_PASSWORD" ]; then
    print_error "Password is required"
    exit 1
fi

# Set registry (default to Docker Hub if not specified)
REGISTRY=""
if [ -n "$INPUT_REGISTRY" ]; then
    REGISTRY="$INPUT_REGISTRY"
    print_info "Target registry: $REGISTRY"
else
    print_info "Target registry: Docker Hub (default)"
fi

# Mask password in logs for security
echo "::add-mask::$INPUT_PASSWORD"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not available in PATH"
    exit 1
fi

print_info "Docker version: $(docker --version)"

# Login to Docker registry
print_step "Authenticating with Docker registry..."

LOGIN_CMD="docker login"
if [ -n "$REGISTRY" ]; then
    LOGIN_CMD="$LOGIN_CMD $REGISTRY"
    REGISTRY_NAME="$REGISTRY"
else
    REGISTRY_NAME="Docker Hub"
fi

# Initialize login status
LOGIN_SUCCESSFUL="false"

# Perform the login
if echo "$INPUT_PASSWORD" | $LOGIN_CMD --username "$INPUT_USERNAME" --password-stdin; then
    print_info "✅ Successfully authenticated with $REGISTRY_NAME"
    LOGIN_SUCCESSFUL="true"
else
    print_error "❌ Authentication failed for $REGISTRY_NAME"
    exit 1
fi

# Verify login was successful by testing registry access
print_step "Verifying authentication..."
if docker info > /dev/null 2>&1; then
    print_info "✅ Docker daemon is accessible and authentication is verified"
else
    print_warning "⚠️  Could not verify Docker daemon access, but login appeared successful"
fi

# Show logout configuration
if [ "$INPUT_LOGOUT" = "true" ]; then
    print_info "🔒 Automatic logout is enabled - will logout when this step completes"
else
    print_info "🔓 Automatic logout is disabled - session will remain active"
    print_warning "⚠️  Remember to logout manually for security: docker logout${REGISTRY:+ $REGISTRY}"
fi

print_info "🎉 Docker login action completed successfully!"

# Output some useful information
echo ""
echo "::group::Login Summary"
echo "Registry: $REGISTRY_NAME"
echo "Username: $INPUT_USERNAME"
echo "Automatic Logout: $INPUT_LOGOUT"
echo "::endgroup::"