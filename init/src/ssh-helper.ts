import * as core from '@actions/core';
import * as exec from '@actions/exec';
import * as io from '@actions/io';
import * as path from 'path';
import * as os from 'os';
import * as fs from 'fs/promises';
import * as crypto from 'crypto';
import { SSHConfig, GitEnvironment } from './types';

export class SSHHelper {
  private readonly config: SSHConfig;

  constructor() {
    this.config = {
      sshSocketPath: path.join(os.tmpdir(), `ssh-auth-sock-${crypto.randomBytes(6).toString('hex')}`),
      sshDir: path.join(os.homedir(), '.ssh'),
      knownHostsFile: path.join(os.homedir(), '.ssh', 'known_hosts')
    };
  }

  /**
   * Initialize SSH configuration
   */
  public async initialize(): Promise<string> {
    try {
      core.debug('Initializing SSH configuration');
      await this.setupSSHDir();
      await this.startSSHAgent();
      await this.configureKnownHosts();
      await this.addSSHKey();
      core.debug('SSH configuration completed successfully');
      return this.config.sshSocketPath;
    } catch (error) {
      throw new Error(`SSH initialization failed: ${(error as Error).message}`);
    }
  }

  /**
   * Setup SSH directory with proper permissions
   */
  private async setupSSHDir(): Promise<void> {
    try {
      core.debug(`Creating SSH directory: ${this.config.sshDir}`);
      await io.mkdirP(this.config.sshDir);
      await fs.chmod(this.config.sshDir, 0o700);
    } catch (error) {
      throw new Error(`Failed to setup SSH directory: ${(error as Error).message}`);
    }
  }

  /**
   * Start SSH agent with custom socket
   */
  private async startSSHAgent(): Promise<void> {
    try {
      core.debug(`Starting SSH agent with socket: ${this.config.sshSocketPath}`);
      await exec.exec('ssh-agent', ['-a', this.config.sshSocketPath]);
    } catch (error) {
      throw new Error(`Failed to start SSH agent: ${(error as Error).message}`);
    }
  }

  /**
   * Configure known hosts file
   */
  private async configureKnownHosts(): Promise<void> {
    try {
      core.debug('Configuring known hosts');
      await exec.exec('ssh-keyscan', ['-H', 'github.com'], {
        outFile: this.config.knownHostsFile
      } as any);
      await fs.chmod(this.config.knownHostsFile, 0o600);
    } catch (error) {
      throw new Error(`Failed to configure known hosts: ${(error as Error).message}`);
    }
  }

  /**
   * Add SSH key from environment variable
   */
  private async addSSHKey(): Promise<void> {
    const sshKey = process.env['SSH_PRIVATE_KEY'];
    if (!sshKey) {
      throw new Error('SSH_PRIVATE_KEY secret is not set');
    }

    try {
      core.debug('Adding SSH key');
      await exec.exec('ssh-add', ['-'], {
        env: { SSH_AUTH_SOCK: this.config.sshSocketPath },
        input: Buffer.from(sshKey)
      });
    } catch (error) {
      throw new Error(`Failed to add SSH key: ${(error as Error).message}`);
    }
  }

  /**
   * Clean up SSH agent
   */
  public async cleanup(): Promise<void> {
    try {
      core.debug('Cleaning up SSH configuration');
      await exec.exec('ssh-add', ['-D'], {
        env: { SSH_AUTH_SOCK: this.config.sshSocketPath }
      });
    } catch (error) {
      core.warning(`SSH cleanup failed: ${(error as Error).message}`);
    }
  }

  /**
   * Get environment variables for Git operations
   */
  public getGitEnv(): GitEnvironment {
    return {
      SSH_AUTH_SOCK: this.config.sshSocketPath,
      GIT_SSH_COMMAND: 'ssh -o StrictHostKeyChecking=yes'
    };
  }
}
