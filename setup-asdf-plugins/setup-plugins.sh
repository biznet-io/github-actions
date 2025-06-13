#!/bin/bash

# Exit on any error, undefined variable, or pipe failure.
set -euo pipefail

# Enable debug mode if DEBUG is set or GitHub Actions debug is enabled
[[ "${DEBUG:-}" == "true" || "${RUNNER_DEBUG:-}" == "1" ]] && set -x

# Get configuration from environment variables
PLUGINS_JSON="${ASDF_PLUGINS:-}"
ADD_TO_PATH="${ASDF_ADD_TO_PATH:-}"

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

# Debug JSON content
debug_json() {
    log_debug "=== JSON Debug Information ==="
    log_debug "ASDF_PLUGINS length: ${#PLUGINS_JSON}"
    log_debug "First 200 chars: ${PLUGINS_JSON:0:200}"
    log_debug "Last 200 chars: ${PLUGINS_JSON: -200}"

    # Check for common issues
    if [[ "$PLUGINS_JSON" == *$'\r'* ]]; then
        log_warning "Detected Windows line endings (\\r) in JSON"
    fi

    if [[ "$PLUGINS_JSON" == *$'\t'* ]]; then
        log_debug "Detected tab characters in JSON"
    fi

    # Try to pretty print if possible
    if echo "$PLUGINS_JSON" | jq . >/dev/null 2>&1; then
        log_debug "JSON structure:"
        echo "$PLUGINS_JSON" | jq . 2>/dev/null | head -20 | while read -r line; do
            log_debug "  $line"
        done
    fi
    log_debug "=== End JSON Debug ==="
}

# Validate environment variables
validate_environment() {
    if [[ -z "$PLUGINS_JSON" ]]; then
        log_error "ASDF_PLUGINS environment variable is required but not set."
        log_error "Please set ASDF_PLUGINS with a JSON array of plugins to install."
        log_error ""
        log_error "Example:"
        log_error "  env:"
        log_error "    ASDF_PLUGINS: |"
        log_error "      ["
        log_error "        {\"name\": \"deno\", \"version\": \"2.3.1\"},"
        log_error "        {\"name\": \"java\", \"version\": \"adoptopenjdk-17.0.14+7\"}"
        log_error "      ]"
        return 1
    fi

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Please install jq in your runner."
        return 1
    fi

    # Debug JSON content if debug mode is enabled
    if [[ "${DEBUG:-}" == "true" || "${RUNNER_DEBUG:-}" == "1" ]]; then
        debug_json
    fi

    # Validate JSON format
    local jq_error
    if ! jq_error=$(echo "$PLUGINS_JSON" | jq empty 2>&1); then
        log_error "Invalid JSON format in ASDF_PLUGINS environment variable"
        log_error "jq error: $jq_error"
        debug_json
        return 1
    fi

    # Check if it's an array
    local json_type
    json_type=$(echo "$PLUGINS_JSON" | jq -r 'type' 2>/dev/null || echo "unknown")
    if [[ "$json_type" != "array" ]]; then
        log_error "ASDF_PLUGINS must be a JSON array, got: $json_type"
        debug_json
        return 1
    fi
}

# Check if plugin is already added
is_plugin_added() {
    local plugin_name="$1"
    asdf plugin list | grep -q "^${plugin_name}$"
}

# Add plugin if not already added
add_plugin() {
    local plugin_name="$1"
    local plugin_url="${2:-}"

    if is_plugin_added "$plugin_name"; then
        log_info "Plugin '$plugin_name' is already added"
        return 0
    fi

    log_info "Adding plugin '$plugin_name'..."

    if [[ -n "$plugin_url" ]]; then
        log_debug "Using custom URL: $plugin_url"
        asdf plugin add "$plugin_name" "$plugin_url"
    else
        log_debug "Using default plugin repository"
        asdf plugin add "$plugin_name"
    fi

    log_success "Plugin '$plugin_name' added successfully"
}

# Install and configure a single plugin
install_plugin() {
    local plugin_name="$1"
    local plugin_version="$2"
    local plugin_url="${3:-}"
    local plugin_env="${4:-{}}"

    start_group "Setting up $plugin_name"

    # Add plugin
    add_plugin "$plugin_name" "$plugin_url"

    # Install version
    log_info "Installing $plugin_name version $plugin_version..."
    asdf install "$plugin_name" "$plugin_version"

    # Set global version
    log_info "Setting global version for $plugin_name to $plugin_version..."
    asdf set "$plugin_name" "$plugin_version"

    # Get installation path
    local install_path
    install_path=$(echo "$(asdf where "$plugin_name")")

    if [[ -z "$install_path" ]]; then
        log_error "Failed to get installation path for $plugin_name"
        end_group
        return 1
    fi

    log_info "Installed $plugin_name at: $install_path"

    # Handle environment variables
    if [[ "$plugin_env" != "{}" && "$plugin_env" != "null" ]]; then
        log_info "Setting up environment variables for $plugin_name..."
        log_debug "Plugin env JSON: $plugin_env"

        # Validate JSON before processing
        if echo "$plugin_env" | jq empty 2>/dev/null; then
            # Parse and set environment variables
            while IFS= read -r env_var; do
                if [[ -n "$env_var" && "$env_var" != "null" ]]; then
                    local var_name var_value
                    var_name=$(echo "$env_var" | cut -d'=' -f1)
                    var_value=$(echo "$env_var" | cut -d'=' -f2-)

                    # Replace placeholder with actual install path
                    var_value="${var_value//\{install_path\}/$install_path}"

                    # Export for current session
                    export "$var_name"="$var_value"

                    # Add to GitHub Actions environment
                    echo "$var_name=$var_value" >> "$GITHUB_ENV"

                    log_info "Set $var_name=$var_value"
                fi
            done < <(echo "$plugin_env" | jq -r 'to_entries[]? | "\(.key)=\(.value)"' 2>/dev/null || true)
        else
            log_warning "Invalid JSON in env section for $plugin_name, skipping environment variables"
            log_debug "Invalid JSON: $plugin_env"
            log_debug "JSON validation error: $jq_env_error"
            log_debug "Raw plugin data: $plugin_data"
        fi
    fi

    # Check if plugin should be added to PATH
    if [[ ",$ADD_TO_PATH," == *",$plugin_name,"* ]]; then
        local bin_path="$install_path/bin"
        if [[ -d "$bin_path" ]]; then
            log_info "Adding $plugin_name to PATH: $bin_path"
            export PATH="$bin_path:$PATH"
            echo "$bin_path" >> "$GITHUB_PATH"
        else
            log_warning "Binary directory not found for $plugin_name: $bin_path"
        fi
    fi

    # Try to get version info for verification
    local version_info=""
    case "$plugin_name" in
        "deno")
            version_info=$(deno --version 2>/dev/null | head -1 || echo "Version check failed")
            ;;
        "java")
            version_info=$(java -version 2>&1 | head -1 || echo "Version check failed")
            ;;
        "node")
            version_info=$(node --version 2>/dev/null || echo "Version check failed")
            ;;
        "python")
            version_info=$(python --version 2>/dev/null || echo "Version check failed")
            ;;
        "golang")
            version_info=$(go version 2>/dev/null || echo "Version check failed")
            ;;
        "rust")
            version_info=$(rustc --version 2>/dev/null || echo "Version check failed")
            ;;
        *)
            # Try common version flags
            if command -v "$plugin_name" &> /dev/null; then
                version_info=$("$plugin_name" --version 2>/dev/null || "$plugin_name" -v 2>/dev/null || "$plugin_name" version 2>/dev/null || echo "Version check available")
            else
                version_info="Installed successfully"
            fi
            ;;
    esac

    log_info "$plugin_name: $version_info"
    log_success "$plugin_name setup completed"

    end_group

    # Return the installation path
    echo "$install_path"
}

# Main installation function
main() {
    log_info "Starting ASDF plugins setup..."
    log_info "Configuration source: Environment variables"

    log_debug "ASDF_PLUGINS: $PLUGINS_JSON"
    log_debug "ASDF_ADD_TO_PATH: $ADD_TO_PATH"

    # Validate environment
    validate_environment

    # Parse plugins array
    local plugins_count
    plugins_count=$(echo "$PLUGINS_JSON" | jq length 2>/dev/null || echo "0")

    if [[ "$plugins_count" == "0" ]]; then
        log_error "No valid plugins found in ASDF_PLUGINS"
        log_debug "ASDF_PLUGINS content: $PLUGINS_JSON"
        return 1
    fi

    log_info "Found $plugins_count plugin(s) to install"

    # Initialize results object
    local installed_plugins="{}"

    # Process each plugin
    for ((i=0; i<plugins_count; i++)); do
        local plugin_data
        plugin_data=$(echo "$PLUGINS_JSON" | jq -r ".[$i]" 2>/dev/null || echo "{}")

        if [[ "$plugin_data" == "{}" || "$plugin_data" == "null" ]]; then
            log_error "Failed to extract plugin data at index $i"
            continue
        fi

        log_debug "Processing plugin at index $i: $plugin_data"

        local plugin_name plugin_version plugin_url plugin_env
        plugin_name=$(echo "$plugin_data" | jq -r '.name // empty' 2>/dev/null || echo "")
        plugin_version=$(echo "$plugin_data" | jq -r '.version // empty' 2>/dev/null || echo "")
        plugin_url=$(echo "$plugin_data" | jq -r '.url // empty' 2>/dev/null || echo "")

        # Handle env extraction more carefully
        if echo "$plugin_data" | jq -e '.env' >/dev/null 2>&1; then
            plugin_env=$(echo "$plugin_data" | jq -c '.env' 2>/dev/null || echo "{}")
        else
            plugin_env="{}"
        fi

        log_debug "Extracted plugin data:"
        log_debug "  name: '$plugin_name'"
        log_debug "  version: '$plugin_version'"
        log_debug "  url: '$plugin_url'"
        log_debug "  env: '$plugin_env'"

        # Validate required fields
        if [[ -z "$plugin_name" || -z "$plugin_version" ]]; then
            log_error "Plugin at index $i is missing required 'name' or 'version' field"
            continue
        fi

        log_debug "Processing plugin: $plugin_name@$plugin_version"

        # Install plugin and get path
        local install_path
        if install_path=$(install_plugin "$plugin_name" "$plugin_version" "$plugin_url" "$plugin_env"); then
            # Add to results
            installed_plugins=$(echo "$installed_plugins" | jq --arg name "$plugin_name" --arg path "$install_path" '. + {($name): $path}')
        else
            log_error "Failed to install plugin: $plugin_name"
            exit 1
        fi
    done

    # Log summary
    start_group "Installation Summary"
    log_info "Successfully installed plugins:"
    echo "$installed_plugins" | jq -r 'to_entries[] | "  \(.key): \(.value)"'

    if [[ -n "$ADD_TO_PATH" ]]; then
        log_info "Added to PATH: $ADD_TO_PATH"
    fi
    end_group

    log_success "🎉 ASDF plugins setup completed successfully!"
}

# Run main function
main "$@"
