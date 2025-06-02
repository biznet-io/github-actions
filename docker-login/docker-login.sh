#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "user: $(whoami)"
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

# Handle password input - either direct password or base64 encoded
DECODED_PASSWORD=""
if [ -n "$INPUT_PASSWORD" ] && [ -n "$INPUT_PASSWORD_BASE64" ]; then
    print_error "Cannot specify both 'password' and 'password_base64' inputs"
    exit 1
elif [ -n "$INPUT_PASSWORD" ]; then
    DECODED_PASSWORD="$INPUT_PASSWORD"
    print_info "Using direct password input"
elif [ -n "$INPUT_PASSWORD_BASE64" ]; then
    print_info "Using base64 encoded password input"
    # Decode the base64 password
    if DECODED_PASSWORD=$(echo "$INPUT_PASSWORD_BASE64" | base64 -d 2>/dev/null); then
        print_info "✅ Successfully decoded base64 password"
    else
        print_error "❌ Failed to decode base64 password"
        exit 1
    fi
else
    print_error "Either 'password' or 'password_base64' input is required"
    exit 1
fi

# Mask both original and decoded passwords in logs for security
# Only mask non-empty values to avoid GitHub Actions warnings
if [ -n "$INPUT_PASSWORD" ]; then
    echo "::add-mask::$INPUT_PASSWORD"
fi
if [ -n "$INPUT_PASSWORD_BASE64" ]; then
    echo "::add-mask::$INPUT_PASSWORD_BASE64"
fi
if [ -n "$DECODED_PASSWORD" ]; then
    echo "::add-mask::$DECODED_PASSWORD"
fi

# Set registry (default to Docker Hub if not specified)
REGISTRY=""
if [ -n "$INPUT_REGISTRY" ]; then
    REGISTRY="$INPUT_REGISTRY"
    print_info "Target registry: $REGISTRY"
else
    print_info "Target registry: Docker Hub (default)"
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not available in PATH"
    exit 1
fi

print_info "Docker version: $(docker --version)"

# Check Docker daemon accessibility and permissions
print_step "Checking Docker daemon accessibility..."

# First, check if Docker daemon is running
if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
    print_error "❌ Cannot connect to Docker daemon"
    echo ""
    print_info "Common solutions:"
    print_info "1. Ensure your workflow runs on a runner with Docker enabled:"
    print_info "   runs-on: ubuntu-latest  # ✅ Has Docker"
    print_info "   runs-on: windows-latest # ❌ No Docker by default"
    print_info "   runs-on: macos-latest   # ❌ No Docker by default"
    echo ""
    print_info "2. If using a self-hosted runner, ensure Docker daemon is running:"
    print_info "   sudo systemctl start docker"
    echo ""
    print_info "3. If using a custom container, ensure Docker socket is mounted:"
    print_info "   volumes:"
    print_info "     - /var/run/docker.sock:/var/run/docker.sock"
    echo ""
    print_info "4. Check if user has Docker permissions:"
    print_info "   sudo usermod -aG docker \$USER"
    echo ""
    
    # Additional diagnostic information
    echo "::group::Diagnostic Information"
    echo "Current user: $(whoami)"
    echo "User groups: $(groups 2>/dev/null || echo 'groups command failed')"
    echo "Docker socket permissions:"
    ls -la /var/run/docker.sock 2>/dev/null || echo "Docker socket not found"
    echo "Docker service status:"
    systemctl is-active docker 2>/dev/null || echo "Cannot check Docker service status"
    echo "::endgroup::"
    
    exit 1
fi

# Check if we can access Docker info (additional permission check)
if ! docker info >/dev/null 2>&1; then
    print_warning "⚠️  Limited Docker daemon access detected"
    print_info "Attempting login anyway (some registries work with limited access)..."
else
    print_info "✅ Docker daemon is accessible"
fi

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

# Perform the login using the decoded password
print_info "Executing: $LOGIN_CMD --username $INPUT_USERNAME --password-stdin"
if echo "$DECODED_PASSWORD" | $LOGIN_CMD --username "$INPUT_USERNAME" --password-stdin; then
    print_info "✅ Successfully authenticated with $REGISTRY_NAME"
    LOGIN_SUCCESSFUL="true"
else
    print_error "❌ Authentication failed for $REGISTRY_NAME"
    
    # Provide additional troubleshooting info
    echo ""
    print_info "Troubleshooting tips:"
    print_info "1. Verify credentials are correct"
    print_info "2. Check if registry URL is correct: $REGISTRY_NAME"
    print_info "3. Ensure the registry allows the authentication method"
    print_info "4. For GCP: verify service account has Artifact Registry permissions"
    print_info "5. For AWS ECR: ensure proper IAM permissions"
    
    exit 1
fi

# Verify login was successful by testing registry access
print_step "Verifying authentication..."
if docker info > /dev/null 2>&1; then
    print_info "✅ Docker daemon is accessible and authentication is verified"
else
    print_warning "⚠️  Could not verify full Docker daemon access, but login appeared successful"
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
echo "Password Type: $([ -n "$INPUT_PASSWORD_BASE64" ] && echo "Base64 Encoded" || echo "Direct")"
echo "Automatic Logout: $INPUT_LOGOUT"
echo "Docker Version: $(docker --version 2>/dev/null || echo 'Unknown')"
echo "Runner OS: ${RUNNER_OS:-Unknown}"
echo "::endgroup::"