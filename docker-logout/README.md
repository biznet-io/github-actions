# Docker Logout Action

This action provides a secure way to logout from Docker registries, complementing the `docker-login` action.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `registry` | Docker registry URL to logout from (defaults to Docker Hub if not specified) | No | `''` |

## Usage

### Basic logout (Docker Hub)

```yaml
- name: Logout from Docker Hub
  uses: whoz/github-actions/docker-logout@main
```

### Logout from specific registry

```yaml
- name: Logout from GitHub Container Registry
  uses: whoz/github-actions/docker-logout@main
  with:
    registry: ghcr.io
```

### Complete workflow example

```yaml
name: Build and Push Docker Image
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to Docker Hub
        uses: whoz/github-actions/docker-login@main
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
      
      - name: Build and push Docker image
        run: |
          docker build -t myapp:latest .
          docker push myapp:latest
      
      - name: Logout from Docker Hub
        if: always()  # Ensure logout runs even if previous steps fail
        uses: whoz/github-actions/docker-logout@main
```

## Auto-detection

This action can automatically detect the registry to logout from if it was set by the `docker-login` action in the same job, so you often don't need to specify the registry parameter explicitly.

## Security Best Practices

- Always use `if: always()` condition to ensure logout runs even if the job fails
- Place the logout step at the end of your job
- Consider using this action in combination with the `docker-login` action for secure authentication workflows