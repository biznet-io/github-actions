# Docker Login Action

This action provides a complete Docker authentication solution with automatic logout functionality built-in.

## Features

- ✅ Custom implementation (no external dependencies)
- ✅ Support for any Docker registry (Docker Hub, GitHub Container Registry, AWS ECR, etc.)
- ✅ **Automatic logout** - securely logout when the step completes
- ✅ Secure password masking in logs
- ✅ Automatic authentication verification
- ✅ Colored output for better readability
- ✅ Comprehensive error handling

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `registry` | Docker registry URL (defaults to Docker Hub if not specified) | No | `''` |
| `username` | Username for Docker registry authentication | Yes | - |
| `password` | Password or token for Docker registry authentication | Yes | - |
| `logout` | Automatically logout when the step completes | No | `true` |

## Usage

### Login to Docker Hub (with automatic logout)

```yaml
- name: Login to Docker Hub
  uses: whoz/github-actions/docker-login@main
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
    # logout: true (default)
```

### Login to GitHub Container Registry

```yaml
- name: Login to GitHub Container Registry
  uses: whoz/github-actions/docker-login@main
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

### Login to Amazon ECR

```yaml
- name: Login to Amazon ECR
  uses: whoz/github-actions/docker-login@main
  with:
    registry: 123456789012.dkr.ecr.us-west-2.amazonaws.com
    username: AWS
    password: ${{ steps.ecr-login.outputs.password }}
```

### Login without automatic logout

```yaml
- name: Login to Docker Registry (persistent session)
  uses: whoz/github-actions/docker-login@main
  with:
    registry: my-registry.example.com
    username: ${{ secrets.REGISTRY_USERNAME }}
    password: ${{ secrets.REGISTRY_PASSWORD }}
    logout: false  # Keep session active
```

## Complete Docker Workflow Example

```yaml
name: Build and Push Docker Image
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to GitHub Container Registry
        uses: whoz/github-actions/docker-login@main
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          # Automatic logout happens when this step completes
      
      - name: Build and push Docker image
        run: |
          docker build -t ghcr.io/${{ github.repository }}:latest .
          docker push ghcr.io/${{ github.repository }}:latest
          
      # No manual logout step needed! 🎉
```

## How Automatic Logout Works

When `logout: true` (default), the action:

1. **Performs login** - Authenticates with the specified registry
2. **Executes your workflow steps** - Your Docker commands run with authentication
3. **Automatically logs out** - When the login step completes, logout happens automatically via shell trap

This ensures:
- ✅ **Security**: Credentials are cleaned up automatically
- ✅ **Simplicity**: No need for separate logout steps
- ✅ **Reliability**: Logout happens even if subsequent steps fail

## Security Features

- **Password Masking**: Automatically masks passwords in GitHub Actions logs
- **Input Validation**: Validates required inputs before attempting login
- **Authentication Verification**: Verifies that Docker daemon is accessible after login
- **Automatic Cleanup**: Securely logout when step completes (unless disabled)
- **Error Handling**: Clear error messages and proper exit codes

## Error Handling

The action will fail with a clear error message if:
- Required inputs (username, password) are missing
- Docker is not available in the runner
- Authentication fails
- Docker daemon is not accessible

## Migration from Separate Actions

If you were using separate `docker-login` and `docker-logout` actions:

**Before:**
```yaml
- name: Login
  uses: whoz/github-actions/docker-login@main
  with:
    username: ${{ secrets.USERNAME }}
    password: ${{ secrets.PASSWORD }}

# ... your steps ...

- name: Logout
  if: always()
  uses: whoz/github-actions/docker-logout@main
```

**After:**
```yaml
- name: Login (with automatic logout)
  uses: whoz/github-actions/docker-login@main
  with:
    username: ${{ secrets.USERNAME }}
    password: ${{ secrets.PASSWORD }}
    # logout: true (default - automatic cleanup!)

# ... your steps ...
# No manual logout needed! 🎉
```

## Notes

- This is a custom implementation that doesn't rely on external actions
- Automatic logout is enabled by default for security
- For Docker Hub, you can omit the `registry` parameter
- Always use secrets for sensitive information like passwords and tokens
- The logout happens when the login step completes, not at the end of the job