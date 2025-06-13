# Setup ASDF Plugins Action

This GitHub Action installs and configures any ASDF plugins with specified versions. It's completely agnostic and can handle any plugin supported by ASDF.

## Features

- **Plugin Agnostic**: Works with any ASDF plugin (Deno, Java, Node.js, Python, Go, Rust, etc.)
- **Flexible Configuration**: Supports custom plugin URLs and environment variables
- **PATH Management**: Automatically adds specified plugins to PATH
- **Environment Variables**: Supports setting custom environment variables per plugin
- **Comprehensive Output**: Returns installation paths for all plugins
- **Error Handling**: Robust error handling with detailed logging
- **Debug Support**: Debug mode support via `RUNNER_DEBUG` or `DEBUG` environment variables

## Usage

### Basic Usage with Input Parameters

```yaml
- name: Setup ASDF Plugins
  uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {"name": "deno", "version": "2.3.1"},
        {"name": "java", "version": "adoptopenjdk-17.0.14+7"}
      ]
```

### Simple Usage with Global Environment Variables

```yaml
# Set once at the workflow or job level
env:
  ASDF_PLUGINS: |
    [
      {"name": "deno", "version": "2.3.1"},
      {"name": "java", "version": "adoptopenjdk-17.0.14+7", "env": {"JAVA_HOME": "{install_path}"}}
    ]
  ASDF_ADD_TO_PATH: "deno"

jobs:
  my-job:
    runs-on: ubuntu-latest
    steps:
      - name: Setup ASDF Plugins
        uses: ./setup-asdf-plugins
        # No inputs needed! Uses environment variables
```

### Advanced Usage with Custom Configuration

```yaml
- name: Setup ASDF Plugins
  uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {
          "name": "deno",
          "version": "2.3.1"
        },
        {
          "name": "java",
          "version": "adoptopenjdk-17.0.14+7",
          "env": {
            "JAVA_HOME": "{install_path}"
          }
        },
        {
          "name": "node",
          "version": "20.10.0",
          "url": "https://github.com/asdf-vm/asdf-nodejs.git"
        }
      ]
    add-to-path: "deno,node"
```

### Using Outputs

```yaml
- name: Setup ASDF Plugins
  id: asdf-setup
  uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {"name": "deno", "version": "2.3.1"},
        {"name": "java", "version": "adoptopenjdk-17.0.14+7"}
      ]

- name: Use installation paths
  run: |
    echo "Installed plugins: ${{ steps.asdf-setup.outputs.installed-plugins }}"
    
    # Parse JSON output to get specific paths
    DENO_PATH=$(echo '${{ steps.asdf-setup.outputs.installed-plugins }}' | jq -r '.deno')
    JAVA_PATH=$(echo '${{ steps.asdf-setup.outputs.installed-plugins }}' | jq -r '.java')
    
    echo "Deno installed at: $DENO_PATH"
    echo "Java installed at: $JAVA_PATH"
```

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `plugins` | JSON array of plugins to install (see format below). If not provided, uses `ASDF_PLUGINS` environment variable. | No* | `""` |
| `add-to-path` | Comma-separated list of plugin names to add to PATH. If not provided, uses `ASDF_ADD_TO_PATH` environment variable. | No | `""` |

*Either `plugins` input or `ASDF_PLUGINS` environment variable must be provided.

### Environment Variable Configuration

You can configure the action using environment variables instead of inputs:

- **`ASDF_PLUGINS`**: JSON array of plugins (same format as `plugins` input)
- **`ASDF_ADD_TO_PATH`**: Comma-separated list of plugin names to add to PATH

Environment variables are used as fallbacks when the corresponding input is not provided.

### Plugin Object Format

Each plugin in the `plugins` array can have the following properties:

```json
{
  "name": "plugin-name",           // Required: Plugin name
  "version": "version-string",     // Required: Version to install
  "url": "https://...",           // Optional: Custom plugin repository URL
  "env": {                        // Optional: Environment variables to set
    "VAR_NAME": "value",
    "ANOTHER_VAR": "{install_path}/sub/path"
  }
}
```

**Special Placeholders:**
- `{install_path}` in environment variable values will be replaced with the actual installation path

## Outputs

| Name | Description |
|------|-------------|
| `installed-plugins` | JSON object with plugin names as keys and installation paths as values |

## Environment Variables

The action automatically sets environment variables for subsequent steps:

1. **PATH Updates**: For plugins listed in `add-to-path`, their `bin` directories are added to PATH
2. **Custom Variables**: Any variables specified in the `env` section of plugin configurations
3. **GitHub Actions Environment**: All variables are persisted for subsequent workflow steps

## Common Plugin Examples

### Deno + Java (Your Original Use Case)

**Using Input Parameters:**
```yaml
- uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {"name": "deno", "version": "2.3.1"},
        {
          "name": "java", 
          "version": "adoptopenjdk-17.0.14+7",
          "env": {"JAVA_HOME": "{install_path}"}
        }
      ]
    add-to-path: "deno"
```

**Using Environment Variables (Recommended for Reusability):**
```yaml
# Set at workflow level
env:
  ASDF_PLUGINS: |
    [
      {"name": "deno", "version": "2.3.1"},
      {
        "name": "java", 
        "version": "adoptopenjdk-17.0.14+7",
        "env": {"JAVA_HOME": "{install_path}"}
      }
    ]
  ASDF_ADD_TO_PATH: "deno"

jobs:
  my-job:
    runs-on: ubuntu-latest
    steps:
      - name: Setup ASDF Plugins
        uses: ./setup-asdf-plugins
        # No inputs needed!
```

### Node.js Development Stack

```yaml
- uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {"name": "node", "version": "20.10.0"},
        {"name": "yarn", "version": "1.22.19"},
        {"name": "python", "version": "3.11.7"}
      ]
    add-to-path: "node,yarn,python"
```

### Go Development

```yaml
- uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {
          "name": "golang",
          "version": "1.21.5",
          "env": {
            "GOROOT": "{install_path}",
            "GOPATH": "$HOME/go"
          }
        }
      ]
    add-to-path: "golang"
```

### Rust Development

```yaml
- uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {
          "name": "rust",
          "version": "1.75.0",
          "env": {
            "CARGO_HOME": "{install_path}/.cargo",
            "RUSTUP_HOME": "{install_path}/.rustup"
          }
        }
      ]
    add-to-path: "rust"
```

## Prerequisites

This action requires:

1. **ASDF**: Must be installed and available in the runner
2. **jq**: Required for JSON parsing (usually pre-installed in GitHub runners)
3. **Plugin Repositories**: Plugins must be available in ASDF's plugin registry or you must provide custom URLs

### Basic Setup

```yaml
- name: Install ASDF
  uses: asdf-vm/actions/setup@v3

- name: Setup ASDF Plugins
  uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {"name": "deno", "version": "2.3.1"}
      ]
```

### With Custom Plugin URLs

```yaml
- name: Setup ASDF Plugins
  uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {
          "name": "deno",
          "version": "2.3.1",
          "url": "https://github.com/asdf-community/asdf-deno.git"
        },
        {
          "name": "java",
          "version": "adoptopenjdk-17.0.14+7",
          "url": "https://github.com/halcyon/asdf-java.git"
        }
      ]
```

## Error Handling

The action includes comprehensive error handling:

- **JSON Validation**: Validates input format before processing
- **Plugin Availability**: Checks if plugins can be added successfully
- **Installation Verification**: Verifies each plugin installs correctly
- **Path Validation**: Ensures binary paths exist before adding to PATH
- **Fail Fast**: Stops execution on first critical error

## Debug Mode

Enable debug logging by setting environment variables:

```yaml
- uses: ./setup-asdf-plugins
  env:
    DEBUG: true
    # or
    RUNNER_DEBUG: 1
  with:
    plugins: |
      [
        {"name": "deno", "version": "2.3.1"}
      ]
```

## Migration from Hardcoded Version

If you were using the previous version with hardcoded Deno and Java support:

**Old:**
```yaml
- uses: ./setup-asdf-plugins
  with:
    deno-version: '2.3.1'
    java-version: 'adoptopenjdk-17.0.14+7'
```

**New:**
```yaml
- uses: ./setup-asdf-plugins
  with:
    plugins: |
      [
        {"name": "deno", "version": "2.3.1"},
        {
          "name": "java", 
          "version": "adoptopenjdk-17.0.14+7",
          "env": {"JAVA_HOME": "{install_path}"}
        }
      ]
    add-to-path: "deno"
```