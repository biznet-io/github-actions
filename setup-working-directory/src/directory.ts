import * as path from 'path'
import * as fs from 'fs'
import { WorkingDirectoryConfig } from './types'

export class DirectoryManager {
  private readonly config: WorkingDirectoryConfig

  constructor(config: WorkingDirectoryConfig) {
    this.config = config
  }

  /**
   * Sanitize path to prevent path traversal
   */
  private sanitizePath(inputPath: string): string {
    return path.normalize(inputPath).replace(/^(\.\.(\/|\\|$))+/, '')
  }

  /**
   * Get the working directory path
   */
  getWorkingDirectoryPath(): string {
    const sanitizedBase = this.sanitizePath(this.config.basePath)
    return path.join(sanitizedBase, this.config.repository, 'branches', this.config.ref)
  }

  /**
   * Create the working directory
   */
  createWorkingDirectory(): void {
    const dirPath = this.getWorkingDirectoryPath()
    try {
      fs.mkdirSync(dirPath, { recursive: true })
    } catch (error) {
      throw new Error(`Failed to create working directory ${dirPath}: ${(error as Error).message}`)
    }
  }
}
