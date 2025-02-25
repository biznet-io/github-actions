import * as core from '@actions/core';
import { getInputs, getConfig } from './config';
import { DirectoryManager } from './directory';

export async function run(): Promise<void> {
  try {
    core.debug('Starting setup-working-directory action');

    // Get inputs and configuration
    const inputs = getInputs();
    const config = getConfig(inputs);

    // Create directory manager
    const directoryManager = new DirectoryManager(config);

    // Create working directory
    directoryManager.createWorkingDirectory();

    // Get the working directory path
    const workingDirectory = directoryManager.getWorkingDirectoryPath();
    
    core.debug(`Working directory path: ${workingDirectory}`);

    // Set outputs
    core.info(`Setting WORKING_DIRECTORY: ${workingDirectory}`);
    core.exportVariable('WORKING_DIRECTORY', workingDirectory);
    core.setOutput('working-directory', workingDirectory);

    core.debug('Setup working directory completed successfully');
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'An unknown error occurred';
    core.setFailed(`Action failed: ${errorMessage}`);
    throw error;
  }
}

// Run the action if this is the main module
if (require.main === module) {
  run().catch(error => {
    core.setFailed(error instanceof Error ? error.message : 'An unknown error occurred');
  });
}