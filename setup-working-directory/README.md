# Setup Working Directory Action

Sets up a standardized working directory structure for GitHub Actions workflows.

## Features

- Creates consistent working directory structure
- Uses repository variables for configuration
- Secure path handling
- Detailed logging and error reporting

## Usage

```yaml
- uses: whoz/setup-working-directory@v1
  with:
    path: ''  # Optional: custom base path
```

## Configuration

### Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `path` | Custom base path for working directory | No | '' |

### Environment Variables

| Name | Description | Required |
|------|-------------|----------|
| `WORKING_DIRECTORY_PREFIX` | Base prefix for working directories | Yes |

### Outputs

| Name | Description |
|------|-------------|
| `working-directory` | Full path of created working directory |

## Examples

### Basic usage

```yaml
steps:
  - uses: whoz/setup-working-directory@v1
    
  - name: Use working directory
    run: |
      cd ${{ env.WORKING_DIRECTORY }}
      # Your commands here
```

### With custom path

```yaml
steps:
  - uses: whoz/setup-working-directory@v1
    with:
      path: '/custom/base/path'
```

## Directory Structure

```
{WORKING_DIRECTORY_PREFIX or path}/
└── {owner}/{repo}/
    └── branches/
        └── {branch}
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

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT