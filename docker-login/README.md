# Docker Login Action

This action provides a complete Docker authentication solution with automatic logout functionality built-in. Supports both regular passwords and base64-encoded credentials (perfect for GCP service account keys).

## Features

- ✅ Custom implementation (no external dependencies)
- ✅ Support for any Docker registry (Docker Hub, GitHub Container Registry, AWS ECR, **GCP Artifact Registry**, etc.)
- ✅ **Base64 password support** - perfect for GCP service account keys
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
| `password` | Password or token for Docker registry authentication | No* | `''` |
| `password_base64` | Base64 encoded password (will be decoded before use) | No* | `''` |
| `logout` | Automatically logout when the step completes | No | `true` |

*Either `password` or `password_base64` must be provided, but not both.

## Usage

### Login to Docker Hub

```yaml
- name: Login to Docker Hub
  uses: whoz/github-actions/docker-login@main
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}
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

### Login to GCP Artifact Registry (Base64 Service Account Key)

```yaml
- name: Login to GCP Artifact Registry
  uses: whoz/github-actions/docker-login@main
  with:
    registry: europe-west1-docker.pkg.dev
    username: _json_key
    password_base64: ${{ secrets.GCP_SA_KEY }}  # Base64 encoded service account JSON
```

This is equivalent to:
```bash
base64 -d $GCP_SA_KEY | docker login -u _json_key --password-stdin https://europe-west1-docker.pkg.dev
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

## Complete GCP Workflow Example

```yaml
name: Build and Push to GCP Artifact Registry
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to GCP Artifact Registry
        uses: whoz/github-actions/docker-login@main
        with:
          registry: europe-west1-docker.pkg.dev
          username: _json_key
          password_base64: ${{ secrets.GCP_SA_KEY }}
          # Automatic logout when this step completes! 🎉
      
      - name: Build and push Docker image
        run: |
          IMAGE="europe-west1-docker.pkg.dev/my-project/my-repo/my-app:latest"
          docker build -t $IMAGE .
          docker push $IMAGE
          
      # No manual logout step needed! ✨
```

## Setting up GCP Service Account Key

1. **Create a service account** in GCP Console
2. **Generate a JSON key** for the service account
3. **Base64 encode the key**:
   ```bash
   cat service-account-key.json | base64 -w 0
   ```
4. **Store the base64 string** in GitHub Secrets as `GCP_SA_KEY`
5. **Use in the action** with `password_base64` input

## How Automatic Logout Works

When `logout: true` (default), the action:

1. **Performs login** - Authenticates with the specified registry
2. **Executes your workflow steps** - Your Docker commands run with authentication
3. **Automatically logs out** - When the login step completes, logout happens automatically via shell trap

This ensures:
- ✅ **Security**: Credentials are cleaned up automatically
- ✅ **Simplicity**: No need for separate logout steps
- ✅ **Reliability**: Logout happens even if subsequent steps fail

## Password Input Options

### Option 1: Direct Password
```yaml
with:
  password: ${{ secrets.MY_PASSWORD }}
```

### Option 2: Base64 Encoded Password
```yaml
with:
  password_base64: ${{ secrets.MY_BASE64_PASSWORD }}
```

**When to use base64:**
- GCP service account JSON keys
- Passwords containing special characters that might cause shell issues
- Multi-line credentials
- When your secret is already base64 encoded

## Security Features

- **Password Masking**: Automatically masks both original and decoded passwords in GitHub Actions logs
- **Input Validation**: Validates required inputs and prevents conflicting password inputs
- **Authentication Verification**: Verifies that Docker daemon is accessible after login
- **Automatic Cleanup**: Securely logout when step completes (unless disabled)
- **Error Handling**: Clear error messages and proper exit codes

## Error Handling

The action will fail with a clear error message if:
- Required inputs (username, password/password_base64) are missing
- Both password and password_base64 are provided
- Base64 decoding fails
- Docker is not available in the runner
- Authentication fails
- Docker daemon is not accessible

## Migration Examples

### From manual GCP commands:
**Before:**
```yaml
- name: Login to GCP
  run: |
    echo ${{ secrets.GCP_SA_KEY }} | base64 -d | docker login -u _json_key --password-stdin https://europe-west1-docker.pkg.dev
- name: Build and push
  run: docker build -t europe-west1-docker.pkg.dev/my-project/my-repo/app:latest .
- name: Logout
  run: docker logout europe-west1-docker.pkg.dev
```

**After:**
```yaml
- name: Login to GCP Artifact Registry
  uses: whoz/github-actions/docker-login@main
  with:
    registry: europe-west1-docker.pkg.dev
    username: _json_key
    password_base64: ${{ secrets.GCP_SA_KEY }}
- name: Build and push
  run: docker build -t europe-west1-docker.pkg.dev/my-project/my-repo/app:latest .
# No manual logout needed! 🎉
```

## Notes

- This is a custom implementation that doesn't rely on external actions
- Automatic logout is enabled by default for security
- For Docker Hub, you can omit the `registry` parameter
- Always use secrets for sensitive information like passwords and tokens
- The logout happens when the login step completes, not at the end of the job
- Base64 decoding uses the standard `base64 -d` command available in GitHub runners