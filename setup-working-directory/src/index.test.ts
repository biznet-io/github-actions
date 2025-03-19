import * as path from 'path'
import * as core from '@actions/core'

// Import after mocks
jest.mock('@actions/core', () => ({
  getInput: jest.fn(),
  exportVariable: jest.fn(),
  setOutput: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  setFailed: jest.fn(),
}))

// Import after all mocks are set up
import { run } from '../src/index'

// Mock @actions/core
jest.mock('@actions/core', () => ({
  getInput: jest.fn(),
  exportVariable: jest.fn(),
  setOutput: jest.fn(),
  debug: jest.fn(),
  info: jest.fn(),
  setFailed: jest.fn(),
}))

// Mock DirectoryManager
jest.mock('../src/directory', () => {
  return {
    DirectoryManager: jest.fn().mockImplementation((config) => ({
      createWorkingDirectory: jest.fn(),
      getWorkingDirectoryPath: jest.fn().mockImplementation(() => {
        // Normalize and sanitize path as the real implementation does
        const sanitizedBase = path.normalize(config.basePath || '').replace(/^(\.\.(\/|\\|$))+/, '')
        return path.join(sanitizedBase, config.repository, 'branches', config.ref)
      }),
    })),
  }
})

describe('setup-working-directory', () => {
  const originalEnv = process.env
  const defaultPrefix = '/tmp/test'

  beforeEach(() => {
    jest.resetModules()
    jest.clearAllMocks()
    process.env = {
      ...originalEnv,
      GITHUB_REPOSITORY: 'owner/repo',
      GITHUB_REF: 'refs/heads/main',
      WORKING_DIRECTORY_PREFIX: defaultPrefix,
    }
  })

  afterEach(() => {
    process.env = originalEnv
  })

  it('creates working directory with default path', async () => {
    // Mock core.getInput to return empty string (default)
    ;(core.getInput as jest.Mock).mockReturnValue('')

    // Run the action
    await run()

    // Expected working directory
    const expectedDir = path.join(defaultPrefix, 'owner/repo', 'branches', 'refs/heads/main')

    // Verify environment variable was set
    expect(core.exportVariable).toHaveBeenCalledWith('WORKING_DIRECTORY', expectedDir)

    // Verify output was set
    expect(core.setOutput).toHaveBeenCalledWith('working-directory', expectedDir)
  })

  it('creates working directory with custom path', async () => {
    // Mock custom path input
    const customPath = '/custom/path'
    ;(core.getInput as jest.Mock).mockReturnValue(customPath)

    // Run the action
    await run()

    // Expected working directory
    const expectedDir = path.join(customPath, 'owner/repo', 'branches', 'refs/heads/main')

    // Verify environment variable was set
    expect(core.exportVariable).toHaveBeenCalledWith('WORKING_DIRECTORY', expectedDir)

    // Verify output was set
    expect(core.setOutput).toHaveBeenCalledWith('working-directory', expectedDir)
  })

  it('sanitizes path traversal attempts', async () => {
    // Mock path with traversal attempt
    const maliciousPath = '../../../etc'
    ;(core.getInput as jest.Mock).mockReturnValue(maliciousPath)

    // Run the action
    await run()

    // Expected directory (traversal attempts removed)
    const expectedDir = path.join(
      'etc', // traversal attempts should be removed
      'owner/repo',
      'branches',
      'refs/heads/main'
    )

    // Verify sanitized path was used
    expect(core.exportVariable).toHaveBeenCalledWith('WORKING_DIRECTORY', expectedDir)
  })

  it('handles missing GITHUB_REPOSITORY variable', async () => {
    // Remove required env variable
    delete process.env.GITHUB_REPOSITORY

    // Run the action and expect it to fail with specific message
    await expect(run()).rejects.toThrow('GITHUB_REPOSITORY environment variable is not set')

    // Verify failure was reported with correct message
    expect(core.setFailed).toHaveBeenCalledWith(expect.stringMatching(/GITHUB_REPOSITORY.*not set/))
  })

  it('handles missing GITHUB_REF variable', async () => {
    // Remove required env variable
    delete process.env.GITHUB_REF

    // Run the action and expect it to fail with specific message
    await expect(run()).rejects.toThrow('GITHUB_REF environment variable is not set')

    // Verify failure was reported with correct message
    expect(core.setFailed).toHaveBeenCalledWith(expect.stringMatching(/GITHUB_REF.*not set/))
  })
})
