import * as fs from 'fs'
import * as path from 'path'
import { DirectoryManager } from './directory'
import { WorkingDirectoryConfig } from './types'

// Mock fs module
jest.mock('fs')

describe('DirectoryManager', () => {
  const defaultConfig: WorkingDirectoryConfig = {
    basePath: '/tmp/test',
    repository: 'owner/repo',
    ref: 'refs/heads/main',
  }

  beforeEach(() => {
    jest.clearAllMocks()
    ;(fs.mkdirSync as jest.Mock).mockImplementation(() => undefined)
  })

  describe('Path Management', () => {
    it('generates correct working directory path', () => {
      const manager = new DirectoryManager(defaultConfig)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('/tmp/test', 'owner/repo', 'branches', 'refs/heads/main'))
    })

    it('handles empty base path', () => {
      const config = { ...defaultConfig, basePath: '' }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('owner/repo', 'branches', 'refs/heads/main'))
    })
  })

  describe('Path Sanitization', () => {
    it('prevents path traversal attempts', () => {
      const config = {
        ...defaultConfig,
        basePath: '../../../etc',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('etc', 'owner/repo', 'branches', 'refs/heads/main'))
    })

    it('handles double slashes in paths', () => {
      const config = {
        ...defaultConfig,
        basePath: '/tmp//test/',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('/tmp/test', 'owner/repo', 'branches', 'refs/heads/main'))
    })

    it('normalizes path separators', () => {
      const config = {
        ...defaultConfig,
        basePath: '/tmp\\test/path',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('/tmp/test/path', 'owner/repo', 'branches', 'refs/heads/main'))
    })

    it('handles dot segments in paths', () => {
      const config = {
        ...defaultConfig,
        basePath: '/tmp/./test/../test',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('/tmp/test', 'owner/repo', 'branches', 'refs/heads/main'))
    })

    it('sanitizes repository path', () => {
      const config = {
        ...defaultConfig,
        repository: '../dangerous/repo',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).not.toContain('..')
    })

    it('sanitizes ref path', () => {
      const config = {
        ...defaultConfig,
        ref: '../dangerous/ref',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).not.toContain('..')
    })
  })

  describe('Directory Creation', () => {
    it('creates directory with recursive option', () => {
      const manager = new DirectoryManager(defaultConfig)
      manager.createWorkingDirectory()
      expect(fs.mkdirSync).toHaveBeenCalledWith(expect.any(String), { recursive: true })
    })

    it('throws error when directory creation fails', () => {
      const error = new Error('Permission denied')
      ;(fs.mkdirSync as jest.Mock).mockImplementation(() => {
        throw error
      })

      const manager = new DirectoryManager(defaultConfig)
      expect(() => manager.createWorkingDirectory()).toThrow(
        `Failed to create working directory ${manager.getWorkingDirectoryPath()}: Permission denied`
      )
    })

    it('handles EEXIST error gracefully', () => {
      const error = new Error('EEXIST: file already exists')
      ;(fs.mkdirSync as jest.Mock).mockImplementation(() => {
        throw error
      })

      const manager = new DirectoryManager(defaultConfig)
      expect(() => manager.createWorkingDirectory()).toThrow(
        `Failed to create working directory ${manager.getWorkingDirectoryPath()}: EEXIST: file already exists`
      )
    })

    it('handles EACCES error with detailed message', () => {
      const error = new Error('EACCES: permission denied')
      ;(fs.mkdirSync as jest.Mock).mockImplementation(() => {
        throw error
      })

      const manager = new DirectoryManager(defaultConfig)
      expect(() => manager.createWorkingDirectory()).toThrow(
        `Failed to create working directory ${manager.getWorkingDirectoryPath()}: EACCES: permission denied`
      )
    })

    it('handles ENOSPC error appropriately', () => {
      const error = new Error('ENOSPC: no space left on device')
      ;(fs.mkdirSync as jest.Mock).mockImplementation(() => {
        throw error
      })

      const manager = new DirectoryManager(defaultConfig)
      expect(() => manager.createWorkingDirectory()).toThrow(
        `Failed to create working directory ${manager.getWorkingDirectoryPath()}: ENOSPC: no space left on device`
      )
    })
  })

  describe('Special Characters Handling', () => {
    it('handles spaces in paths', () => {
      const config = {
        ...defaultConfig,
        basePath: '/tmp/test path/with spaces',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('/tmp/test path/with spaces', 'owner/repo', 'branches', 'refs/heads/main'))
    })

    it('handles special characters in repository name', () => {
      const config = {
        ...defaultConfig,
        repository: 'owner/repo-with-@#$',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('/tmp/test', 'owner/repo-with-@#$', 'branches', 'refs/heads/main'))
    })

    it('handles unicode characters in paths', () => {
      const config = {
        ...defaultConfig,
        basePath: '/tmp/tést/páth',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('/tmp/tést/páth', 'owner/repo', 'branches', 'refs/heads/main'))
    })

    it('handles special characters in ref', () => {
      const config = {
        ...defaultConfig,
        ref: 'refs/heads/feature/special@branch#123',
      }
      const manager = new DirectoryManager(config)
      const dirPath = manager.getWorkingDirectoryPath()
      expect(dirPath).toBe(path.join('/tmp/test', 'owner/repo', 'branches', 'refs/heads/feature/special@branch#123'))
    })
  })
})
