# Migrating from Composite to JavaScript Actions

This guide explains how to migrate from the composite actions to the new JavaScript versions.

## Overview of Changes

- Actions rewritten in JavaScript for better maintainability
- Enhanced error handling and logging
- Improved security features
- Better typing and validation
- Same functionality with improved reliability

## Setup Working Directory Action

### Before (Composite)
```yaml
- uses: ./.github/actions/setup-working-directory
  with:
    path: ''
```

### After (JavaScript)
```yaml
- uses: ./setup-working-directory
  with:
    path: ''
```

No changes required in your workflow configuration. The action maintains the same inputs and outputs.

### Environment Variables
- `WORKING_DIRECTORY_PREFIX` (repository variable) - remains unchanged
- The action will still set `WORKING_DIRECTORY` for subsequent steps

## Init Action

### Before (Composite)
```yaml
- uses: ./.github/actions/init
  with:
    WORKING_DIRECTORY: ${{ env.WORKING_DIRECTORY }}
```

### After (JavaScript)
```yaml
- uses: ./init
  with:
    WORKING_DIRECTORY: ${{ env.WORKING_DIRECTORY }}
  env:
    SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
    INIT_REPOSITORY_PIPELINE_ID_ENV_FILE: ${{ vars.INIT_REPOSITORY_PIPELINE_ID_ENV_FILE }}
```

### Required Configuration
1. Set up SSH key as a secret:
   ```yaml
   # Repository Settings > Secrets
   SSH_PRIVATE_KEY: your-ssh-private-key
   ```

2. Set up repository variables:
   ```yaml
   # Repository Settings > Variables
   INIT_REPOSITORY_PIPELINE_ID_ENV_FILE: pipeline.env
   ```

## Testing the Migration

1. Create a test branch
2. Update one workflow to use new actions
3. Verify functionality
4. Roll out to other workflows

## Rollback Plan

If issues occur:
1. Revert to composite actions branch
2. Update workflow to use composite actions
3. Report issues in the repository

## Common Issues

### SSH Key Issues
- Ensure SSH_PRIVATE_KEY is properly set
- Check key permissions in the error logs
- Verify key has repository access

### Working Directory Issues
- Confirm WORKING_DIRECTORY_PREFIX is set
- Check path permissions
- Review logs for path construction details

## Validation Steps

1. Pull Request workflows work correctly
2. Repository caching functions as expected
3. SSH operations complete successfully
4. Working directory is properly set up