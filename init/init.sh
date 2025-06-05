#!/bin/bash

# Exit on any error, undefined variable, or pipe failure
set -euo pipefail

# Enable debug mode if DEBUG is set or GitHub Actions debug is enabled
[[ "${DEBUG:-}" == "true" || "${RUNNER_DEBUG:-}" == "1" ]] && set -x

# Constants
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
readonly INIT_REPOSITORY_PIPELINE_ID_ENV_FILE="${INIT_REPOSITORY_PIPELINE_ID_ENV_FILE:-pipeline_id.env}"

# Global variables
WORKING_DIRECTORY=""
SSH_SOCK=""
WORKING_BRANCH=""

# Cleanup function to be called on exit
cleanup() {
    local exit_code=$?
    if [[ -n "${SSH_SOCK:-}" && -S "$SSH_SOCK" ]]; then
        echo "🧹 Cleaning up SSH agent..."
        SSH_AUTH_SOCK="$SSH_SOCK" ssh-add -D 2>/dev/null || true
        ssh-agent -k 2>/dev/null || true
    fi
    exit $exit_code
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# GitHub Actions logging functions
log_info() {
    echo "ℹ️  $*"
}

log_error() {
    echo "::error::$*" >&2
    echo "❌ ERROR: $*" >&2
}

log_warning() {
    echo "::warning::$*"
    echo "⚠️  WARNING: $*"
}

log_success() {
    echo "✅ $*"
}

log_debug() {
    if [[ "${DEBUG:-}" == "true" || "${RUNNER_DEBUG:-}" == "1" ]]; then
        echo "::debug::$*"
        echo "🐛 DEBUG: $*"
    fi
}

# GitHub Actions grouping
start_group() {
    echo "::group::$1"
}

end_group() {
    echo "::endgroup::"
}

# Validation functions
validate_environment() {
    local required_vars=(
        "GITHUB_REPOSITORY"
        "GITHUB_ACTOR"
        "GITHUB_RUN_ID"
        "SSH_PRIVATE_KEY"
    )

    log_debug "Validating GitHub Actions environment..."
    log_debug "GITHUB_EVENT_NAME: ${GITHUB_EVENT_NAME:-}"
    log_debug "GITHUB_REF: ${GITHUB_REF:-}"
    log_debug "GITHUB_REF_NAME: ${GITHUB_REF_NAME:-}"
    log_debug "GITHUB_REF_TYPE: ${GITHUB_REF_TYPE:-}"
    log_debug "GITHUB_BASE_REF: ${GITHUB_BASE_REF:-}"
    log_debug "GITHUB_HEAD_REF: ${GITHUB_HEAD_REF:-}"

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable $var is not set"
            return 1
        fi
    done

    # Validate GitHub context
    if [[ ! "${GITHUB_REPOSITORY:-}" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid GITHUB_REPOSITORY format: ${GITHUB_REPOSITORY:-}"
        return 1
    fi
}

validate_working_directory() {
    if [[ -z "$WORKING_DIRECTORY" ]]; then
        log_error "Working directory parameter is required"
        return 1
    fi

    if [[ ! "$WORKING_DIRECTORY" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
        log_error "Working directory contains invalid characters"
        return 1
    fi
}

validate_working_branch() {
    if [[ -n "$WORKING_BRANCH" ]]; then
        # Validate branch name follows Git naming conventions
        if [[ ! "$WORKING_BRANCH" =~ ^[a-zA-Z0-9._/-]+$ ]] || [[ "$WORKING_BRANCH" =~ ^\.|\.$ ]] || [[ "$WORKING_BRANCH" =~ \.\.|\.lock$ ]] || [[ "$WORKING_BRANCH" =~ ^/ ]] || [[ "$WORKING_BRANCH" =~ /$ ]]; then
            log_error "Invalid branch name: $WORKING_BRANCH"
            log_error "Branch names cannot start/end with '.', contain '..', end with '.lock', or start/end with '/'"
            return 1
        fi
        log_debug "Branch name validation passed: $WORKING_BRANCH"
    fi
}

# SSH setup functions
setup_ssh() {
    start_group "Setting up SSH authentication"

    # Create unique, secure socket
    SSH_SOCK=$(mktemp -u)
    log_debug "Created SSH socket: $SSH_SOCK"

    # Start SSH agent with unique socket
    if ! ssh-agent -a "$SSH_SOCK" > /dev/null; then
        log_error "Failed to start SSH agent"
        end_group
        return 1
    fi
    log_debug "SSH agent started successfully"

    # Configure SSH directory and known hosts
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh

    # Add GitHub to known hosts with timeout
    if ! timeout 30 ssh-keyscan -H github.com >> ~/.ssh/known_hosts; then
        log_error "Failed to add GitHub to known hosts (timeout or connection failure)"
        end_group
        return 1
    fi
    log_debug "GitHub added to known hosts"

    # Add SSH key with strict permissions
    if ! SSH_AUTH_SOCK="$SSH_SOCK" ssh-add - <<< "${SSH_PRIVATE_KEY}" 2>/dev/null; then
        log_error "Failed to add SSH key (check key format and permissions)"
        end_group
        return 1
    fi

    log_success "SSH authentication configured"
    end_group
}

# Git configuration functions
configure_git() {
    log_info "Configuring Git..."

    git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
    git config --global user.name "${GITHUB_ACTOR}"
    git config --global merge.directoryRenames false

    log_success "Git configured"
}

determine_working_branch() {
    log_info "Determining working branch..."

    if [[ "${GITHUB_EVENT_NAME:-}" == "pull_request" ]]; then
        # For pull requests, use the base branch
        WORKING_BRANCH="${GITHUB_BASE_REF:-main}"
        log_info "Pull request detected, using base branch: $WORKING_BRANCH"
    elif [[ -n "${GITHUB_REF_NAME:-}" ]]; then
        # For pushes or other events with a ref
        WORKING_BRANCH="$GITHUB_REF_NAME"
        log_info "Using ref name: $WORKING_BRANCH"
    else
        # Fallback to main
        log_error "No specific branch detected"
        return 1
    fi

    log_info "GITHUB_REF_TYPE: ${GITHUB_REF_TYPE:-}"
    log_success "Working branch set to: $WORKING_BRANCH"
}

# Cache management functions
check_repository_cache() {
    local pipeline_file="$WORKING_DIRECTORY/$INIT_REPOSITORY_PIPELINE_ID_ENV_FILE"

    if [[ -f "$pipeline_file" ]]; then
        source "$pipeline_file"
        if [[ "${INIT_REPOSITORY_PIPELINE_ID:-}" == "$GITHUB_RUN_ID" ]]; then
            log_info "Manual re-run detected, clearing repository cache..."
            cd "$WORKING_DIRECTORY/.."
            rm -rf "$WORKING_DIRECTORY"
            mkdir -p "$WORKING_DIRECTORY"
            cd "$WORKING_DIRECTORY"
            return 0
        else
            log_info "Automatic execution detected, keeping repository cache"
            return 1
        fi
    else
        log_info "No pipeline ID file found, treating as fresh run"
        return 0
    fi
}

# Git operations with SSH
git_with_ssh() {
    SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git "$@"
}

# Repository initialization functions
clone_repository() {
    log_info "Cloning repository..."

    if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
        local tag_name="${GITHUB_REF_NAME:-$(echo "${GITHUB_REF:-}" | sed 's/refs\/tags\///')}"
        if [[ -z "$tag_name" ]]; then
            log_error "Cannot determine tag name"
            return 1
        fi

        log_info "Cloning and checking out tag: $tag_name"
        git_with_ssh clone "git@github.com:${GITHUB_REPOSITORY}.git" .
        git_with_ssh fetch origin tag "$tag_name"
        git_with_ssh checkout -f "$tag_name"
    else
        log_info "Cloning and checking out branch: $WORKING_BRANCH"
        git_with_ssh clone --depth 1 --branch "$WORKING_BRANCH" "git@github.com:${GITHUB_REPOSITORY}.git" .
    fi

    log_success "Repository cloned successfully"
}

initialize_existing_directory() {
    log_info "Initializing Git in existing directory..."

    git init
    git_with_ssh remote add origin "git@github.com:${GITHUB_REPOSITORY}.git"
    git_with_ssh fetch origin

    if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
        local tag_name="${GITHUB_REF_NAME:-$(echo "${GITHUB_REF:-}" | sed 's/refs\/tags\///')}"
        if [[ -z "$tag_name" ]]; then
            log_error "Cannot determine tag name"
            return 1
        fi

        log_info "Checking out tag: $tag_name"
        git_with_ssh fetch origin tag "$tag_name"
        git_with_ssh checkout -f "$tag_name"
    else
        log_info "Checking out branch: $WORKING_BRANCH"
        if ! git_with_ssh checkout -f "$WORKING_BRANCH"; then
            git_with_ssh checkout -f -b "$WORKING_BRANCH"
        fi
    fi

    log_success "Existing directory initialized"
}

update_existing_repository() {
    log_info "Updating existing repository..."

    git_with_ssh fetch --tags --force

    if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
        local tag_name="${GITHUB_REF_NAME:-$(echo "${GITHUB_REF:-}" | sed 's/refs\/tags\///')}"
        if [[ -z "$tag_name" ]]; then
            log_error "Cannot determine tag name"
            return 1
        fi

        log_info "Checking out tag: $tag_name"
        git_with_ssh checkout -f "$tag_name"
    else
        log_info "Checking out and resetting to branch: $WORKING_BRANCH"
        git_with_ssh checkout -f "$WORKING_BRANCH"
        git_with_ssh reset --hard "origin/$WORKING_BRANCH"
    fi

    log_success "Repository updated"
}

setup_repository() {
    log_info "Setting up repository in: $WORKING_DIRECTORY"

    # Enable git discovery across filesystem
    export GIT_DISCOVERY_ACROSS_FILESYSTEM=true

    # Set Git terminal prompt to avoid issues in CI
    export GIT_TERMINAL_PROMPT=0

    # Check if we need to clear cache
    local cache_cleared=false
    if check_repository_cache; then
        cache_cleared=true
    fi

    if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]] || [[ "$cache_cleared" == "true" ]]; then
        log_info "Repository cache is empty, initializing..."

        if [[ -n "$(ls -A "$WORKING_DIRECTORY" 2>/dev/null)" ]]; then
            log_info "Directory is not empty, initializing Git repository locally"
            initialize_existing_directory
        else
            log_info "Directory is empty, safe to clone"
            clone_repository
        fi
    else
        log_info "Repository cache exists, updating sources..."
        update_existing_repository
    fi

    # Configure merge settings
    git config merge.directoryRenames false
    git_with_ssh fetch --tags --force
}

handle_pull_request() {
    if [[ -z "${GITHUB_BASE_REF:-}" ]]; then
        return 0
    fi

    log_info "Handling pull request workflow..."

    # Extract PR number from GITHUB_REF (format: refs/pull/NUMBER/merge)
    # BASH_REMATCH[0] = full match, BASH_REMATCH[1] = first capture group
    local pr_number
    if [[ "${GITHUB_REF:-}" =~ refs/pull/([0-9]+)/merge ]]; then
        pr_number="${BASH_REMATCH[1]}"  # Extract PR number from capture group
        log_debug "Extracted PR number: $pr_number from GITHUB_REF: ${GITHUB_REF:-}"
    else
        log_error "Cannot extract PR number from GITHUB_REF: ${GITHUB_REF:-}"
        log_error "Expected format: refs/pull/NUMBER/merge"
        return 1
    fi

    log_info "Processing PR #$pr_number"

    # Ensure we have the latest refs and fetch all necessary branches
    git_with_ssh fetch origin
    
    # Fetch the target branch explicitly to ensure it exists locally
    # This ensures origin/$WORKING_BRANCH is available for diff operations
    log_info "Fetching target branch: $WORKING_BRANCH"
    if ! git_with_ssh fetch origin "$WORKING_BRANCH:refs/remotes/origin/$WORKING_BRANCH" 2>/dev/null; then
        # If direct fetch fails, try fetching all refs and create the remote branch reference
        log_warning "Direct branch fetch failed, trying alternative approach..."
        git_with_ssh fetch origin "+refs/heads/$WORKING_BRANCH:refs/remotes/origin/$WORKING_BRANCH" || {
            log_error "Failed to fetch target branch: $WORKING_BRANCH"
            return 1
        }
    fi

    # Fetch the PR merge reference
    git_with_ssh fetch origin "pull/$pr_number/merge:pr-merge"

    # Check out the merge reference to test the merged result
    git_with_ssh checkout pr-merge

    # Verify that the remote branch reference exists for diff operations
    if ! git rev-parse "origin/$WORKING_BRANCH" >/dev/null 2>&1; then
        log_error "Remote branch origin/$WORKING_BRANCH not found after fetch"
        log_info "Available remote branches:"
        git branch -r
        return 1
    fi

    log_success "Pull request merge reference checked out"
    log_info "Remote branch origin/$WORKING_BRANCH is available for diff operations"
}

save_pipeline_id() {
    echo "INIT_REPOSITORY_PIPELINE_ID=$GITHUB_RUN_ID" > "$WORKING_DIRECTORY/$INIT_REPOSITORY_PIPELINE_ID_ENV_FILE"
    log_success "Pipeline ID saved"
}

run_cache_initialization() {
    local cache_script="$SCRIPT_DIR/init-cache.sh"

    if [[ -f "$cache_script" ]]; then
        log_info "Running cache initialization..."
        if ! "$cache_script" "$WORKING_DIRECTORY"; then
            log_error "Cache initialization failed"
            return 1
        fi
        log_success "Cache initialization completed"
    else
        log_info "Cache initialization script not found, skipping"
        return 1
    fi
}

# Set GitHub Actions outputs
set_output() {
    local name="$1"
    local value="$2"

    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "$name=$value" >> "$GITHUB_OUTPUT"
        log_debug "Set output: $name=$value"
    else
        log_warning "GITHUB_OUTPUT not available, cannot set output: $name=$value"
    fi
}

# Add step summary
add_step_summary() {
    local start_timestamp="$1"
    local branch_source="${2:-auto-detected}"
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        cat >> "$GITHUB_STEP_SUMMARY" << EOF
## 🚀 Repository Initialization Summary

- **Repository**: \`${GITHUB_REPOSITORY}\`
- **Working Directory**: \`${WORKING_DIRECTORY}\`
- **Branch/Tag**: \`${WORKING_BRANCH}\` (${GITHUB_REF_TYPE:-branch} - ${branch_source})
- **Event**: \`${GITHUB_EVENT_NAME:-}\`
- **Run ID**: \`${GITHUB_RUN_ID}\`
- **Start Time**: $(date -d "@$start_timestamp" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || date -r "$start_timestamp" '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || echo "$start_timestamp")

### Git Information
- **Commit SHA**: \`$(git rev-parse HEAD 2>/dev/null || echo "N/A")\`
- **Commit Message**: $(git log -1 --pretty=format:"%s" 2>/dev/null || echo "N/A")

✅ **Status**: Repository initialized successfully
EOF
        log_debug "Added step summary"
    fi
}

# Main function
main() {
    local start_time
    start_time=$(date +%s)

    start_group "🚀 Repository Initialization"
    log_info "Starting repository initialization..."

    # Get working directory from first argument
    WORKING_DIRECTORY="${1:-}"

    # Get optional working branch from second argument
    local provided_branch="${2:-}"
    local branch_source="auto-detected"
    if [[ -n "$provided_branch" ]]; then
        WORKING_BRANCH="$provided_branch"
        branch_source="manually provided"
        log_info "Using provided working branch: $WORKING_BRANCH"
    fi

    # Validate inputs
    validate_environment
    validate_working_directory
    validate_working_branch

    # Create and navigate to working directory
    mkdir -p "$WORKING_DIRECTORY"
    cd "$WORKING_DIRECTORY"
    log_info "Working directory: $WORKING_DIRECTORY"

    # Setup components
    setup_ssh
    configure_git

    # Determine working branch only if not provided as argument
    if [[ -z "$WORKING_BRANCH" ]]; then
        determine_working_branch
    fi

    # Setup repository
    start_group "Repository Setup"
    setup_repository
    end_group

    # Handle pull request specifics
    if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
        start_group "Pull Request Handling"
        handle_pull_request
        end_group
    fi

    # Save pipeline state
    save_pipeline_id

    # Run additional cache initialization
        start_group "Cache Initialization"
        run_cache_initialization
        end_group

    # Set outputs for subsequent steps
    set_output "working-directory" "$WORKING_DIRECTORY"
    set_output "working-branch" "$WORKING_BRANCH"
    set_output "git-sha" "$(git rev-parse HEAD 2>/dev/null || echo '')"

    # Add summary
    add_step_summary "$start_time" "$branch_source"

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    log_success "🎉 Repository initialization completed successfully in ${duration}s!"
    end_group
}

# Run main function with all arguments
main "$@"
