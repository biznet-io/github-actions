import { getConfig } from '../config';
import { ActionInputs } from '../types';

describe('config', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it('should get config with all values set', () => {
    // Setup
    const inputs: ActionInputs = {
      path: '/custom/path'
    };
    process.env['GITHUB_REPOSITORY'] = 'owner/repo';
    process.env['GITHUB_REF'] = 'refs/heads/main';
    process.env['WORKING_DIRECTORY_PREFIX'] = '/prefix';

    // Execute
    const config = getConfig(inputs);

    // Verify
    expect(config).toEqual({
      basePath: '/custom/path',
      repository: 'owner/repo',
      ref: 'refs/heads/main'
    });
  });

  it('should use WORKING_DIRECTORY_PREFIX when path is empty', () => {
    // Setup
    const inputs: ActionInputs = {
      path: ''
    };
    process.env['GITHUB_REPOSITORY'] = 'owner/repo';
    process.env['GITHUB_REF'] = 'refs/heads/main';
    process.env['WORKING_DIRECTORY_PREFIX'] = '/prefix';

    // Execute
    const config = getConfig(inputs);

    // Verify
    expect(config.basePath).toBe('/prefix');
  });

  it('should throw error when GITHUB_REPOSITORY is not set', () => {
    // Setup
    const inputs: ActionInputs = {
      path: ''
    };
    process.env['GITHUB_REF'] = 'refs/heads/main';

    // Execute & Verify
    expect(() => getConfig(inputs)).toThrow('GITHUB_REPOSITORY environment variable is not set');
  });

  it('should throw error when GITHUB_REF is not set', () => {
    // Setup
    const inputs: ActionInputs = {
      path: ''
    };
    process.env['GITHUB_REPOSITORY'] = 'owner/repo';

    // Execute & Verify
    expect(() => getConfig(inputs)).toThrow('GITHUB_REF environment variable is not set');
  });
});
