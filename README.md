# GitHub Actions Collection

A collection of JavaScript-based GitHub Actions for repository management and workflow automation.

## Available Actions

### Setup Working Directory
Sets up a standardized working directory structure for workflows.
- [Documentation](./setup-working-directory/README.md)
- [Source](./setup-working-directory)

### Init
Initializes repository with SSH configuration and git setup.
- [Documentation](./init/README.md)
- [Source](./init)

## Migration

If you're migrating from the composite actions, see the [Migration Guide](./MIGRATION.md).

## Development

### Prerequisites
- Node.js 20.x
- npm 9.x

### Setup
1. Clone the repository
2. Install dependencies:
   ```bash
   # For setup-working-directory
   cd setup-working-directory
   npm install

   # For init
   cd ../init
   npm install
   ```

### Building
Each action needs to be built separately:
```bash
# For setup-working-directory
cd setup-working-directory
npm run build

# For init
cd ../init
npm run build
```

### Testing
Run tests for each action:
```bash
# For setup-working-directory
cd setup-working-directory
npm test

# For init
cd ../init
npm test
```

### Workflow Testing
The actions are automatically tested in GitHub Actions:
- [Setup Working Directory Tests](.github/workflows/test-setup-working-directory.yml)
- [Init Tests](.github/workflows/test-init.yml)

## Configuration

### Repository Secrets
Required secrets for the actions:

| Secret | Used By | Description |
|--------|---------|-------------|
| `SSH_PRIVATE_KEY` | init | SSH key for repository access |

### Repository Variables
Required variables for the actions:

| Variable | Used By | Description |
|----------|---------|-------------|
| `WORKING_DIRECTORY_PREFIX` | setup-working-directory | Base path for working directories |
| `INIT_REPOSITORY_PIPELINE_ID_ENV_FILE` | init | File to store pipeline ID |

## Security

- SSH keys are handled securely
- Paths are properly sanitized
- Strict SSH configuration is enforced
- Proper cleanup is performed

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT