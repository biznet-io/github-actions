# Setup ASDF Plugins Action

This GitHub Action installs and configures any ASDF plugins with specified versions using **environment variables only**. It's completely agnostic and can handle any plugin supported by ASDF.

## Features

- **Environment Variable Driven**: Configure everything through environment variables
- **Plugin Agnostic**: Works with any ASDF plugin (Deno, Java, Node.js, Python, Go, Rust, etc.)
- **Flexible Configuration**: Supports custom plugin URLs and environment variables per plugin
- **PATH Management**: Automatically adds specified plugins to PATH
- **Comprehensive Output**: Returns installation paths for all plugins
- **Error Handling**: Robust error handling with detailed logging
- **Debug Support**: Debug mode support via `RUNNER_DEBUG` or `DEBUG` environment variables

## Quick Start

```yaml
name: My Workflow

env:
  ASDF_PLUGINS: |
    [
      {"name": "deno", "version": "2.3.1"},
      {"name": "java", "version": "adoptopenjdk-17.0.14+7", "env": {"JAVA_HOME": "{install_path}"}}
    ]
  ASDF_ADD_TO_PATH: "deno"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      
      - name: Setup Development Tools
        uses: ./setup-asdf-plugins
        # That's it! No configuration needed
      
      - name: Use your tools
        run: |
          deno --version
          java -version
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `ASDF_PLUGINS` | JSON array of plugins to install (see format below) |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `ASDF_ADD_TO_PATH` | Comma-separated list of plugin names to add to PATH | `""` |

## Plugin Configuration Format

The `ASDF_PLUGINS` environment variable should contain a JSON array where each plugin object can have:

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

## Usage Examples

### Basic Development Stack

```yaml
env:
  ASDF_PLUGINS: |
    [
      {"name": "node", "version": "20.10.0"},
      {"name": "python", "version": "3.11.7"},
      {"name": "deno", "version": "2.3.1"}
    ]
  ASDF_ADD_TO_PATH: "node,python,deno"

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      - uses: ./setup-asdf-plugins
      
      - run: |
          node --version
          python --version
          deno --version
```

### Java Development with Environment Variables

```yaml
env:
  ASDF_PLUGINS: |
    [
      {
        "name": "java",
        "version": "adoptopenjdk-17.0.14+7",
        "env": {
          "JAVA_HOME": "{install_path}"
        }
      },
      {"name": "gradle", "version": "8.5"}
    ]
  ASDF_ADD_TO_PATH: "gradle"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      - uses: ./setup-asdf-plugins
      
      - run: |
          echo "JAVA_HOME: $JAVA_HOME"
          java -version
          gradle --version
```

### Go Development with Custom Environment

```yaml
env:
  ASDF_PLUGINS: |
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
  ASDF_ADD_TO_PATH: "golang"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      - uses: ./setup-asdf-plugins
      
      - run: |
          echo "GOROOT: $GOROOT"
          echo "GOPATH: $GOPATH"
          go version
```

### Multi-Language Full Stack

```yaml
env:
  ASDF_PLUGINS: |
    [
      {"name": "node", "version": "20.10.0"},
      {"name": "python", "version": "3.11.7"},
      {
        "name": "java",
        "version": "adoptopenjdk-17.0.14+7",
        "env": {"JAVA_HOME": "{install_path}"}
      },
      {
        "name": "golang", 
        "version": "1.21.5",
        "env": {"GOROOT": "{install_path}"}
      },
      {"name": "rust", "version": "1.75.0"}
    ]
  ASDF_ADD_TO_PATH: "node,python,golang,rust"

jobs:
  test-all:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      - uses: ./setup-asdf-plugins
      
      - name: Test all languages
        run: |
          node --version
          python --version
          java -version
          go version
          rustc --version
```

### Custom Plugin URLs

```yaml
env:
  ASDF_PLUGINS: |
    [
      {
        "name": "deno",
        "version": "2.3.1",
        "url": "https://github.com/asdf-community/asdf-deno.git"
      },
      {
        "name": "java",
        "version": "adoptopenjdk-17.0.14+7",
        "url": "https://github.com/halcyon/asdf-java.git",
        "env": {"JAVA_HOME": "{install_path}"}
      }
    ]
  ASDF_ADD_TO_PATH: "deno"

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      - uses: ./setup-asdf-plugins
```

## Job-Level Configuration

You can override or set different configurations at the job level:

```yaml
# Global default
env:
  ASDF_PLUGINS: |
    [
      {"name": "node", "version": "20.10.0"}
    ]

jobs:
  frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      - uses: ./setup-asdf-plugins  # Uses global Node.js
  
  backend:
    runs-on: ubuntu-latest
    env:
      # Override for this job
      ASDF_PLUGINS: |
        [
          {"name": "java", "version": "adoptopenjdk-17.0.14+7"},
          {"name": "gradle", "version": "8.5"}
        ]
      ASDF_ADD_TO_PATH: "gradle"
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      - uses: ./setup-asdf-plugins  # Uses job-specific Java + Gradle
```

## Outputs

The action provides one output that you can use in subsequent steps:

| Name | Description |
|------|-------------|
| `installed-plugins` | JSON object with plugin names as keys and installation paths as values |

### Using Outputs

```yaml
- name: Setup ASDF Plugins
  id: asdf-setup
  uses: ./setup-asdf-plugins

- name: Use installation paths
  run: |
    echo "All plugins: ${{ steps.asdf-setup.outputs.installed-plugins }}"
    
    # Parse specific paths
    DENO_PATH=$(echo '${{ steps.asdf-setup.outputs.installed-plugins }}' | jq -r '.deno // empty')
    JAVA_PATH=$(echo '${{ steps.asdf-setup.outputs.installed-plugins }}' | jq -r '.java // empty')
    
    if [[ -n "$DENO_PATH" ]]; then
      echo "Deno installed at: $DENO_PATH"
    fi
    
    if [[ -n "$JAVA_PATH" ]]; then
      echo "Java installed at: $JAVA_PATH"
    fi
```

## Prerequisites

1. **ASDF**: Must be installed and available in the runner
2. **jq**: Required for JSON parsing (usually pre-installed in GitHub runners)

### Basic Setup Template

```yaml
name: My Project

env:
  ASDF_PLUGINS: |
    [
      {"name": "your-tool", "version": "your-version"}
    ]

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install ASDF
        uses: asdf-vm/actions/setup@v3

      - name: Setup Development Tools
        uses: ./setup-asdf-plugins

      - name: Build
        run: |
          # Your build commands here
```

## Error Handling

The action includes comprehensive error handling:

- **Environment Validation**: Ensures `ASDF_PLUGINS` is set and valid JSON
- **JSON Validation**: Validates the structure and required fields
- **Plugin Availability**: Checks if plugins can be added successfully
- **Installation Verification**: Verifies each plugin installs correctly
- **Path Validation**: Ensures binary paths exist before adding to PATH
- **Fail Fast**: Stops execution on first critical error

## Troubleshooting

### Common JSON Parsing Errors

If you get errors like "parse error: Unmatched '}'", here are common causes:

#### 1. Invalid JSON Syntax
```yaml
# ❌ Wrong - Missing closing quote
env:
  ASDF_PLUGINS: |
    [
      {"name": "deno, "version": "2.3.1"}
    ]

# ✅ Correct
env:
  ASDF_PLUGINS: |
    [
      {"name": "deno", "version": "2.3.1"}
    ]
```

#### 2. YAML Multiline String Issues
```yaml
# ❌ Wrong - Inconsistent indentation
env:
  ASDF_PLUGINS: |
    [
      {"name": "deno", "version": "2.3.1"},
    {"name": "java", "version": "adoptopenjdk-17.0.14+7"}
    ]

# ✅ Correct - Consistent indentation
env:
  ASDF_PLUGINS: |
    [
      {"name": "deno", "version": "2.3.1"},
      {"name": "java", "version": "adoptopenjdk-17.0.14+7"}
    ]
```

#### 3. Use the Debug Tool

The action includes a debug script to help troubleshoot JSON issues:

```bash
# In your repository
chmod +x setup-asdf-plugins/debug-json.sh

# Set your environment variable
export ASDF_PLUGINS='[{"name": "deno", "version": "2.3.1"}]'

# Run the debug tool
./setup-asdf-plugins/debug-json.sh
```

#### 4. Enable Debug Mode

```yaml
jobs:
  debug-build:
    runs-on: ubuntu-latest
    env:
      DEBUG: true  # Enable detailed logging
      ASDF_PLUGINS: |
        [
          {"name": "deno", "version": "2.3.1"}
        ]
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      - uses: ./setup-asdf-plugins
```

#### 5. Test JSON Locally

You can test your JSON syntax locally:

```bash
# Test if your JSON is valid
echo '[{"name": "deno", "version": "2.3.1"}]' | jq .

# Should output pretty-printed JSON if valid
```

### Common Issues and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `parse error: Unmatched '}'` | Invalid JSON syntax | Check quotes, commas, brackets |
| `ASDF_PLUGINS must be a JSON array` | JSON is object, not array | Wrap in `[...]` |
| `Plugin at index X is missing required 'name' or 'version'` | Missing fields | Ensure all plugins have `name` and `version` |
| `jq is required but not installed` | Missing jq | Use `ubuntu-latest` runner (has jq pre-installed) |

## Debug Mode

Enable debug logging:

```yaml
jobs:
  debug-build:
    runs-on: ubuntu-latest
    env:
      DEBUG: true
      # or RUNNER_DEBUG: 1
      ASDF_PLUGINS: |
        [
          {"name": "deno", "version": "2.3.1"}
        ]
    steps:
      - uses: actions/checkout@v4
      - uses: asdf-vm/actions/setup@v3
      - uses: ./setup-asdf-plugins
```

## Common Plugin Examples

### Popular Development Tools

```yaml
env:
  ASDF_PLUGINS: |
    [
      {"name": "node", "version": "20.10.0"},
      {"name": "python", "version": "3.11.7"},
      {"name": "ruby", "version": "3.2.0"},
      {"name": "golang", "version": "1.21.5"},
      {"name": "rust", "version": "1.75.0"},
      {"name": "deno", "version": "2.3.1"},
      {"name": "bun", "version": "1.0.0"}
    ]
  ASDF_ADD_TO_PATH: "node,python,ruby,golang,rust,deno,bun"
```

### DevOps Tools

```yaml
env:
  ASDF_PLUGINS: |
    [
      {"name": "kubectl", "version": "1.28.4"},
      {"name": "helm", "version": "3.13.2"},
      {"name": "terraform", "version": "1.6.4"},
      {"name": "awscli", "version": "2.13.0"}
    ]
  ASDF_ADD_TO_PATH: "kubectl,helm,terraform,awscli"
```

### Database Tools

```yaml
env:
  ASDF_PLUGINS: |
    [
      {"name": "postgres", "version": "16.1"},
      {"name": "redis", "version": "7.2.3"},
      {"name": "mongodb", "version": "7.0.4"}
    ]
```

## Why Environment Variables Only?

1. **Simplicity**: No input parameters to remember or configure
2. **Reusability**: Define once at workflow level, use everywhere
3. **Consistency**: Same configuration across all jobs
4. **Maintainability**: Single source of truth for tool versions
5. **Flexibility**: Easy to override at job level when needed

This approach makes your workflows cleaner and more maintainable! 🎉