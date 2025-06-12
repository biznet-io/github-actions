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
WORKING_BRANCH=""




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
        "GITHUB_RUN_ID"
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



# Git configuration functions
configure_git() {
    log_info "Configuring Git..."

    git config --global user.email "github-actions@users.noreply.github.com"
    git config --global user.name "github-actions"
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
        git clone git@github.com:${GITHUB_REPOSITORY}.git .
        git fetch origin tag "$tag_name"
        git checkout -f "$tag_name"
    else
        log_info "Cloning and checking out branch: $WORKING_BRANCH"
        git clone --depth 1 --branch "$WORKING_BRANCH" "git@github.com:${GITHUB_REPOSITORY}.git" .
    fi

    log_success "Repository cloned successfully"
}

initialize_existing_directory() {
    log_info "Initializing Git in existing directory..."

    git init
    git remote add origin "git@github.com:${GITHUB_REPOSITORY}.git"
    git fetch origin

    if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
        local tag_name="${GITHUB_REF_NAME:-$(echo "${GITHUB_REF:-}" | sed 's/refs\/tags\///')}"
        if [[ -z "$tag_name" ]]; then
            log_error "Cannot determine tag name"
            return 1
        fi

        log_info "Checking out tag: $tag_name"
        git fetch origin tag "$tag_name"
        git checkout -f "$tag_name"
    else
        log_info "Checking out branch: $WORKING_BRANCH"
        if ! git checkout -f "$WORKING_BRANCH"; then
            git checkout -f -b "$WORKING_BRANCH"
        fi
    fi

    log_success "Existing directory initialized"
}

update_existing_repository() {
    log_info "Updating existing repository..."
    git fetch --tags --force

    if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
        local tag_name="${GITHUB_REF_NAME:-$(echo "${GITHUB_REF:-}" | sed 's/refs\/tags\///')}"
        if [[ -z "$tag_name" ]]; then
            log_error "Cannot determine tag name"
            return 1
        fi

        log_info "Checking out tag: $tag_name"
        git checkout -f "$tag_name"
    else
        log_info "Checking out and resetting to branch: $WORKING_BRANCH"

        # Check if the branch exists locally
        if git show-ref --verify --quiet "refs/heads/$WORKING_BRANCH"; then
            log_info "Local branch exists, checking out: $WORKING_BRANCH"
            git checkout -f "$WORKING_BRANCH"
        else
            log_info "Local branch doesn't exist, creating from remote: $WORKING_BRANCH"
            # Create local branch from remote if it doesn't exist
            git checkout -f -b "$WORKING_BRANCH" "origin/$WORKING_BRANCH"
        fi
        
        # Reset to match remote
        git reset --hard "origin/$WORKING_BRANCH"
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
    git fetch --tags --force
    
    # CRITICAL: For PR contexts, ensure the base branch is available as remote tracking branch
    # This must happen BEFORE any tools try to use origin/branch_name references
    if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
        log_info "Ensuring base branch is available for PR context: $WORKING_BRANCH"
        
        # Fetch all branches to ensure we have complete remote references
        git fetch origin
        
        # Explicitly ensure the base branch exists as a remote tracking branch
        if ! git show-ref --verify --quiet "refs/remotes/origin/$WORKING_BRANCH"; then
            log_info "Creating remote tracking branch for: $WORKING_BRANCH"
            if git fetch origin "+refs/heads/$WORKING_BRANCH:refs/remotes/origin/$WORKING_BRANCH"; then
                log_success "Successfully created remote tracking branch: origin/$WORKING_BRANCH"
            else
                log_error "Failed to create remote tracking branch for: $WORKING_BRANCH"
                log_info "Available remote branches:"
                git branch -r
            fi
        else
            log_info "Remote tracking branch already exists: origin/$WORKING_BRANCH"
        fi
        
        # Verify the reference is accessible
        if git rev-parse "origin/$WORKING_BRANCH" >/dev/null 2>&1; then
            log_success "Verified: origin/$WORKING_BRANCH is accessible"
        else
            log_error "Warning: origin/$WORKING_BRANCH is not accessible for diff operations"
        fi
    fi
}

handle_pull_request() {
    if [[ -z "${GITHUB_BASE_REF:-}" ]]; then
        return 0
    fi

    log_info "Handling pull request workflow..."
    log_debug "GITHUB_BASE_REF: ${GITHUB_BASE_REF:-}"
    log_debug "GITHUB_HEAD_REF: ${GITHUB_HEAD_REF:-}"
    log_debug "WORKING_BRANCH: $WORKING_BRANCH"

    # Extract PR number from GITHUB_REF (format: refs/pull/NUMBER/merge)
    local pr_number
    if [[ "${GITHUB_REF:-}" =~ refs/pull/([0-9]+)/merge ]]; then
        pr_number="${BASH_REMATCH[1]}"
        log_debug "Extracted PR number: $pr_number from GITHUB_REF: ${GITHUB_REF:-}"
    else
        log_error "Cannot extract PR number from GITHUB_REF: ${GITHUB_REF:-}"
        log_error "Expected format: refs/pull/NUMBER/merge"
        return 1
    fi

    log_info "Processing PR #$pr_number"
    
    # Debug: Show current git state
    log_debug "Current git status:"
    git status --porcelain || true
    log_debug "Current branches:"
    git branch -a || true
    log_debug "Current remotes:"
    git remote -v || true

    # Ensure we have all the necessary remote references
    log_info "Fetching all remote references..."
    git fetch origin
    
    # The key insight: in GitHub Actions PR context, we need to ensure that
    # the base branch exists as a remote tracking branch that tools can reference
    log_info "Setting up remote tracking branch for: $WORKING_BRANCH"
    
    # Method 1: Try to fetch the branch directly
    if git fetch origin "$WORKING_BRANCH" 2>/dev/null; then
        log_info "Successfully fetched branch: $WORKING_BRANCH"
    else
        log_warning "Direct fetch of $WORKING_BRANCH failed, trying alternatives..."
    fi
    
    # Method 2: Ensure the remote tracking branch exists
    # This is crucial for tools like NX that expect origin/branch_name to exist
    if ! git rev-parse "refs/remotes/origin/$WORKING_BRANCH" >/dev/null 2>&1; then
        log_info "Creating remote tracking branch: origin/$WORKING_BRANCH"
        
        # Try different approaches to create the remote tracking branch
        if git fetch origin "+refs/heads/$WORKING_BRANCH:refs/remotes/origin/$WORKING_BRANCH" 2>/dev/null; then
            log_success "Created remote tracking branch via explicit refspec"
        elif git show-ref --verify --quiet "refs/remotes/origin/$WORKING_BRANCH"; then
            log_info "Remote tracking branch already exists"
        else
            # Last resort: create a local branch and set up tracking
            log_warning "Attempting to create local branch and set up tracking..."
            if git checkout -b "$WORKING_BRANCH" "origin/$WORKING_BRANCH" 2>/dev/null; then
                git checkout -
                log_info "Created local tracking branch"
            else
                log_error "All methods to create remote tracking branch failed"
                log_info "Available remote branches:"
                git branch -r
                return 1
            fi
        fi
    else
        log_info "Remote tracking branch origin/$WORKING_BRANCH already exists"
    fi

    # Clean up any existing pr-merge branch to handle re-runs
    if git show-ref --verify --quiet refs/heads/pr-merge; then
        log_info "Cleaning up existing pr-merge branch for re-run..."
        git branch -D pr-merge 2>/dev/null || true
    fi
    
    # Fetch the PR merge reference
    log_info "Fetching PR merge reference..."
    git fetch origin "pull/$pr_number/merge:pr-merge"

    # Check out the merge reference to test the merged result
    git checkout pr-merge
    
    # Final verification
    if git rev-parse "origin/$WORKING_BRANCH" >/dev/null 2>&1; then
        log_success "Pull request setup complete - origin/$WORKING_BRANCH is available"
        log_debug "origin/$WORKING_BRANCH points to: $(git rev-parse origin/$WORKING_BRANCH)"
    else
        log_error "Failed to set up origin/$WORKING_BRANCH reference"
        log_info "Current remote branches:"
        git branch -r
        log_info "Attempting to show what exists:"
        git show-ref | grep -E "(origin|$WORKING_BRANCH)" || echo "No matching refs found"
        return 1
    fi

    log_success "Pull request merge reference checked out successfully"
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
