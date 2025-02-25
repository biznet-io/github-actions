import * as core from '@actions/core';
import * as io from '@actions/io';
import { SSHHelper } from './ssh-helper';
import { GitHelper } from './git-helper';
import { ActionInputs } from './types';

async function getInputs(): Promise<ActionInputs> {
  return {
    WORKING_DIRECTORY: core.getInput('WORKING_DIRECTORY', { required: true })
  };
}

async function run(): Promise<void> {
  let sshHelper: SSHHelper | undefined;

  try {
    core.debug('Starting repository initialization');

    // Get and validate inputs
    const inputs = await getInputs();
    
    // Create and change to working directory
    core.debug(`Setting up working directory: ${inputs.WORKING_DIRECTORY}`);
    await io.mkdirP(inputs.WORKING_DIRECTORY);
    process.chdir(inputs.WORKING_DIRECTORY);
    core.info(`Working directory: ${inputs.WORKING_DIRECTORY}`);

    // Initialize SSH
    sshHelper = new SSHHelper();
    await sshHelper.initialize();
    core.info('SSH configuration completed');

    // Initialize Git operations
    const gitHelper = new GitHelper(inputs.WORKING_DIRECTORY, sshHelper);
    await gitHelper.configureGit();
    core.info('Git configuration completed');

    // Handle repository cache and setup
    await gitHelper.handleCache();
    core.info('Repository cache handled');

    // Handle pull request merge if needed
    await gitHelper.handlePullRequestMerge();
    core.info('Repository initialization completed successfully');

  } catch (error) {
    core.setFailed(`Action failed: ${(error as Error).message}`);
    throw error;
  } finally {
    // Cleanup SSH if initialized
    if (sshHelper) {
      try {
        await sshHelper.cleanup();
        core.debug('SSH cleanup completed');
      } catch (error) {
        core.warning(`SSH cleanup failed: ${(error as Error).message}`);
      }
    }
  }
}

// Run the action
if (require.main === module) {
  run().catch(error => {
    core.setFailed((error as Error).message);
  });
}