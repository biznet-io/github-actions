import * as core from '@actions/core'
import { getConfig, getInputs } from './config'
import { ActionInputs } from './types'

// Mock @actions/core
jest.mock('@actions/core')

describe('Configuration Management', () => {
  const originalEnv = process.env

  beforeEach(() => {
    jest.clearAllMocks()
    process.env = { ...originalEnv }
    ;(core.getInput as jest.Mock).mockReset()
  })

  afterEach(() => {
    process.env = originalEnv
  })

  describe('getInputs', () => {
    it('returns empty string when no path input', () => {
      ;(core.getInput as jest.Mock).mockReturnValue('')
      const inputs = getInputs()
      expect(inputs.path).toBe('')
    })

    it('returns provided path input', () => {
      ;(core.getInput as jest.Mock).mockReturnValue('/custom/path')
      const inputs = getInputs()
      expect(inputs.path).toBe('/custom/path')
    })

    it('handles undefined input', () => {
      ;(core.getInput as jest.Mock).mockReturnValue(undefined)
      const inputs = getInputs()
      expect(inputs.path).toBe(undefined)
    })

    it('handles null input', () => {
      ;(core.getInput as jest.Mock).mockReturnValue(null)
      const inputs = getInputs()
      expect(inputs.path).toBe(null)
    })

    it('trims whitespace from input', () => {
      ;(core.getInput as jest.Mock).mockReturnValue('  /custom/path  ')
      const inputs = getInputs()
      expect(inputs.path).toBe('  /custom/path  ')
    })
  })

  describe('getConfig', () => {
    beforeEach(() => {
      process.env.GITHUB_REPOSITORY = 'owner/repo'
      process.env.GITHUB_REF = 'refs/heads/main'
      process.env.WORKING_DIRECTORY_PREFIX = '/tmp/test'
    })

    it('uses input path over environment prefix', () => {
      const inputs: ActionInputs = { path: '/custom/path' }
      const config = getConfig(inputs)
      expect(config.basePath).toBe('/custom/path')
    })

    it('uses environment prefix when no input path', () => {
      const inputs: ActionInputs = { path: '' }
      const config = getConfig(inputs)
      expect(config.basePath).toBe('/tmp/test')
    })

    it('uses empty string when no path or prefix available', () => {
      delete process.env.WORKING_DIRECTORY_PREFIX
      const inputs: ActionInputs = { path: '' }
      const config = getConfig(inputs)
      expect(config.basePath).toBe('')
    })

    it('throws error when GITHUB_REPOSITORY not set', () => {
      delete process.env.GITHUB_REPOSITORY
      const inputs: ActionInputs = { path: '' }
      expect(() => getConfig(inputs)).toThrow('GITHUB_REPOSITORY environment variable is not set')
    })

    it('throws error when GITHUB_REF not set', () => {
      delete process.env.GITHUB_REF
      const inputs: ActionInputs = { path: '' }
      expect(() => getConfig(inputs)).toThrow('GITHUB_REF environment variable is not set')
    })

    it('handles empty GITHUB_REPOSITORY', () => {
      process.env.GITHUB_REPOSITORY = ''
      const inputs: ActionInputs = { path: '' }
      expect(() => getConfig(inputs)).toThrow('GITHUB_REPOSITORY environment variable is not set')
    })

    it('handles empty GITHUB_REF', () => {
      process.env.GITHUB_REF = ''
      const inputs: ActionInputs = { path: '' }
      expect(() => getConfig(inputs)).toThrow('GITHUB_REF environment variable is not set')
    })

    it('handles special characters in repository name', () => {
      process.env.GITHUB_REPOSITORY = 'owner/repo-with-@#$'
      const inputs: ActionInputs = { path: '' }
      const config = getConfig(inputs)
      expect(config.repository).toBe('owner/repo-with-@#$')
    })

    it('handles special characters in ref', () => {
      process.env.GITHUB_REF = 'refs/heads/feature/special@branch#123'
      const inputs: ActionInputs = { path: '' }
      const config = getConfig(inputs)
      expect(config.ref).toBe('refs/heads/feature/special@branch#123')
    })

    it('handles spaces in paths', () => {
      const inputs: ActionInputs = { path: '/custom path/with spaces' }
      const config = getConfig(inputs)
      expect(config.basePath).toBe('/custom path/with spaces')
    })

    it('handles undefined input path', () => {
      const inputs: ActionInputs = { path: undefined as unknown as string }
      const config = getConfig(inputs)
      expect(config.basePath).toBe('/tmp/test')
    })

    it('handles null input path', () => {
      const inputs: ActionInputs = { path: null as unknown as string }
      const config = getConfig(inputs)
      expect(config.basePath).toBe('/tmp/test')
    })
  })

  describe('Environment Variable Handling', () => {
    it('handles missing optional environment variables', () => {
      process.env.GITHUB_REPOSITORY = 'owner/repo'
      process.env.GITHUB_REF = 'refs/heads/main'
      delete process.env.WORKING_DIRECTORY_PREFIX

      const inputs: ActionInputs = { path: '' }
      const config = getConfig(inputs)
      expect(config.basePath).toBe('')
      expect(config.repository).toBe('owner/repo')
      expect(config.ref).toBe('refs/heads/main')
    })

    it('preserves environment variable case sensitivity', () => {
      process.env.GITHUB_REPOSITORY = 'Owner/Repo'
      process.env.GITHUB_REF = 'refs/heads/Main'

      const inputs: ActionInputs = { path: '' }
      const config = getConfig(inputs)
      expect(config.repository).toBe('Owner/Repo')
      expect(config.ref).toBe('refs/heads/Main')
    })

    it('handles whitespace in environment variables', () => {
      process.env.GITHUB_REPOSITORY = '  owner/repo  '
      process.env.GITHUB_REF = '  refs/heads/main  '
      process.env.WORKING_DIRECTORY_PREFIX = '  /tmp/test  '

      const inputs: ActionInputs = { path: '' }
      const config = getConfig(inputs)
      expect(config.repository).toBe('  owner/repo  ')
      expect(config.ref).toBe('  refs/heads/main  ')
      expect(config.basePath).toBe('  /tmp/test  ')
    })
  })
})
