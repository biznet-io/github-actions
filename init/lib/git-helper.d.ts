import { SSHHelper } from './ssh-helper'
export declare class GitHelper {
  private readonly config
  private readonly sshHelper
  private readonly cacheConfig
  constructor(workingDirectory: string, sshHelper: SSHHelper)
  /**
   * Configure global git settings
   */
  configureGit(): Promise<void>
  /**
   * Check if repository has remote origin
   */
  private hasRemoteOrigin
  /**
   * Clone repository
   */
  private cloneRepository
  /**
   * Update existing repository
   */
  private updateRepository
  /**
   * Handle repository cache
   */
  handleCache(): Promise<void>
  /**
   * Handle merge result pipeline for pull requests
   */
  handlePullRequestMerge(): Promise<void>
}
