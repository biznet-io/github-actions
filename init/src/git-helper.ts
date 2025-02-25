import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as io from '@actions/io';
import * as path from 'path';
import * as fs from 'fs/promises';
import { GitConfig, RepositoryCacheConfig } from './types';
import { SSHHelper } from './ssh-helper';

export class GitHelper {
  private readonly config: GitConfig;
  private readonly sshHelper: SSHHelper;
  private readonly cacheConfig: RepositoryCacheConfig;

  constructor(workingDirectory: string, sshHelper: SSHHelper) {
    const repository = process.env['GITHUB_REPOSITORY'];
    const sha = process.env['GITHUB_SHA'];
    const actor = process.env['GITHUB_ACTOR'];
    const ref = process.env['GITHUB_REF'];
    const baseRef = process.env['GITHUB_BASE_REF'];
    const runId = process.env['GITHUB_RUN_ID'];
    const pipelineIdFile = process.env['INIT_REPOSITORY_PIPELINE_ID_ENV_FILE'];

    if (!repository || !sha || !actor || !ref || !runId || !pipelineIdFile) {
      throw new Error('Required environment variables are not set');
    }

    this.config = { repository, sha, actor, ref, baseRef, runId };
    this.sshHelper = sshHelper;
    this.cacheConfig = {
      workingDirectory,
      pipelineIdFile,
      runId
    };
  }

  /**
   * Configure global git settings
   */
  public async configureGit(): Promise<void> {
    try {
      core.debug('Configuring git globals');
      await exec.exec('git', ['config', '--global', 'user.email', `${this.config.actor}@users.noreply.github.com`]);
      await exec.exec('git', ['config', '--global', 'user.name', this.config.actor]);
      await exec.exec('git', ['config', '--global', 'init.defaultBranch', this.config.ref]);
      process.env['GIT_DISCOVERY_ACROSS_FILESYSTEM'] = 'true';
    } catch (error) {
      throw new Error(`Git configuration failed: ${(error as Error).message}`);
    }
  }

  /**
   * Check if repository has remote origin
   */
  private async hasRemoteOrigin(): Promise<boolean> {
    try {
      const { exitCode } = await exec.getExecOutput('git', ['remote'], {
        silent: true,
        ignoreReturnCode: true
      });
      return exitCode === 0;
    } catch (error) {
      return false;
    }
  }

  /**
   * Clone repository
   */
  private async cloneRepository(): Promise<void> {
    try {
      core.debug('Cloning repository');
      await exec.exec('git', [
        'clone',
        '--depth', '1',
        '--branch', this.config.sha,
        `git@github.com:${this.config.repository}.git`,
        '.'
      ], { env: this.sshHelper.getGitEnv() });

      await exec.exec('git', ['config', 'merge.directoryRenames', 'false']);
      await exec.exec('git', ['fetch', '--tags', '--force'], { env: this.sshHelper.getGitEnv() });
    } catch (error) {
      throw new Error(`Repository clone failed: ${(error as Error).message}`);
    }
  }

  /**
   * Update existing repository
   */
  private async updateRepository(): Promise<void> {
    try {
      core.debug('Updating repository');
      await exec.exec('git', ['fetch', '--tags', '--force'], { env: this.sshHelper.getGitEnv() });
      await exec.exec('git', ['reset', '--hard', this.config.sha], { env: this.sshHelper.getGitEnv() });
    } catch (error) {
      throw new Error(`Repository update failed: ${(error as Error).message}`);
    }
  }

  /**
   * Handle repository cache
   */
  public async handleCache(): Promise<void> {
    try {
      const envFilePath = path.join(this.cacheConfig.workingDirectory, this.cacheConfig.pipelineIdFile);
      let previousRunId: string | undefined;

      try {
        const envContent = await fs.readFile(envFilePath, 'utf8');
        previousRunId = envContent?.split('=')[1]?.trim();
        core.debug(`Previous run ID: ${previousRunId}`);
      } catch (error) {
        core.debug('No previous run ID found');
      }

      if (previousRunId === this.cacheConfig.runId) {
        core.info('Job has been manually re-run, removing repository cache');
        await io.rmRF(this.cacheConfig.workingDirectory);
        await io.mkdirP(this.cacheConfig.workingDirectory);
      }

      const hasOrigin = await this.hasRemoteOrigin();
      if (!hasOrigin) {
        await this.cloneRepository();
      } else {
        await this.updateRepository();
      }

      await fs.writeFile(envFilePath, `INIT_REPOSITORY_PIPELINE_ID=${this.cacheConfig.runId}`);
    } catch (error) {
      throw new Error(`Cache handling failed: ${(error as Error).message}`);
    }
  }

  /**
   * Handle merge result pipeline for pull requests
   */
  public async handlePullRequestMerge(): Promise<void> {
    if (!this.config.baseRef) {
      core.debug('Not a pull request, skipping merge handling');
      return;
    }

    try {
      core.debug(`Handling pull request merge with base ref: ${this.config.baseRef}`);
      // Implementation for merge result pipeline would go here
      // This would replicate the functionality from init-merge-result-pipeline.sh
    } catch (error) {
      throw new Error(`Pull request merge handling failed: ${(error as Error).message}`);
    }
  }
}
