import * as core from '@actions/core'
import { ActionInputs, WorkingDirectoryConfig } from './types'

export function getInputs(): ActionInputs {
  return {
    path: core.getInput('path'),
  }
}

export function getConfig(inputs: ActionInputs): WorkingDirectoryConfig {
  const repository = process.env['GITHUB_REPOSITORY']
  const ref = process.env['GITHUB_REF']
  const workingDirPrefix = process.env['WORKING_DIRECTORY_PREFIX']

  if (!repository) {
    throw new Error('GITHUB_REPOSITORY environment variable is not set')
  }

  if (!ref) {
    throw new Error('GITHUB_REF environment variable is not set')
  }

  return {
    basePath: inputs.path || workingDirPrefix || '',
    repository,
    ref,
  }
}
