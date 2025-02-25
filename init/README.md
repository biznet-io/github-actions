# Init Action

Initializes a repository with SSH configuration, git setup, and caching for GitHub Actions workflows.

## Features

- Secure SSH key handling
- Git repository caching
- Pull request merge support
- Comprehensive error handling
- Detailed logging

## Usage

```yaml
- uses: whoz/init@v1
  with:
    WORKING_DIRECTORY: ${{ env.WORKING_DIRECTORY }}
  env:
    SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
    INIT_REPOSITORY_PIPELINE_ID_ENV_FILE: ${{ vars.INIT_REPOSITORY_PIPELINE_ID_ENV_FILE }}
```

## Configuration

### Inputs

| Name | Description | Required |
|------|-------------|----------|
| `WORKING_DIRECTORY` | Directory for repository initialization | Yes |

### Environment Variables

#### Secrets
| Name | Description | Required |
|------|-------------|----------|
| `SSH_PRIVATE_KEY` | SSH key for repository access | Yes |

#### Repository Variables
| Name | Description | Required |
|------|-------------|----------|
| `INIT_REPOSITORY_PIPELINE_ID_ENV_FILE` | File to store pipeline ID | Yes |

### Automatic Variables
These are provided by GitHub Actions:
- `GITHUB_REPOSITORY`
- `GITHUB_SHA`
- `GITHUB_ACTOR`
- `GITHUB_REF`
- `GITHUB_BASE_REF`
- `GITHUB_RUN_ID`

## Examples

### Basic usage

```yaml
steps:
  - uses: whoz/init@v1
    with:
      WORKING_DIRECTORY: ${{ env.WORKING_DIRECTORY }}
    env:
      SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
      INIT_REPOSITORY_PIPELINE_ID_ENV_FILE: pipeline.env
```

### With pull request handling

```yaml
steps:
  - uses: whoz/init@v1
    if: github.event_name == 'pull_request'
    with:
      WORKING_DIRECTORY: ${{ env.WORKING_DIRECTORY }}
    env:
      SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
      INIT_REPOSITORY_PIPELINE_ID_ENV_FILE: pipeline.env
```

## Development

1. Install dependencies:
```bash
npm install
```

2. Build:
```bash
npm run build
```

3. Run tests:
```bash
npm test
```

4. Format and lint:
```bash
npm run all
```

## Security Considerations

- SSH keys are handled securely
- Strict SSH configuration is enforced
- Paths are sanitized
- Proper permissions are set
- Cleanup is performed

## Directory Structure

```
init/
├── dist/           # Compiled action
├── src/            # Source code
│   ├── index.js    # Main entry
│   ├── git-helper.js
│   └── ssh-helper.js
├── __tests__/      # Tests
├── action.yml      # Action definition
└── package.json    # Dependencies
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT