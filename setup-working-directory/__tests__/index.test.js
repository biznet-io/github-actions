const path = require('path');
const core = require('@actions/core');
const fs = require('fs');

// Mock @actions/core
jest.mock('@actions/core');

describe('setup-working-directory', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
    // Mock GitHub environment variables
    process.env.GITHUB_REPOSITORY = 'owner/repo';
    process.env.GITHUB_REF = 'refs/heads/main';
    process.env.WORKING_DIRECTORY_PREFIX = '/tmp/test';
  });

  afterEach(() => {
    process.env = originalEnv;
    jest.clearAllMocks();
  });

  test('creates working directory with default path', async () => {
    // Mock core.getInput to return empty string (default)
    core.getInput.mockReturnValue('');

    // Import the action
    const action = require('../src/index');

    // Run the action
    await action();

    // Expected working directory
    const expectedDir = path.join(
      process.env.WORKING_DIRECTORY_PREFIX,
      process.env.GITHUB_REPOSITORY,
      'branches',
      process.env.GITHUB_REF
    );

    // Verify environment variable was set
    expect(core.exportVariable).toHaveBeenCalledWith(
      'WORKING_DIRECTORY',
      expectedDir
    );

    // Verify output was set
    expect(core.setOutput).toHaveBeenCalledWith(
      'working-directory',
      expectedDir
    );
  });

  test('creates working directory with custom path', async () => {
    // Mock custom path input
    const customPath = '/custom/path';
    core.getInput.mockReturnValue(customPath);

    // Import the action
    const action = require('../src/index');

    // Run the action
    await action();

    // Expected working directory
    const expectedDir = path.join(
      customPath,
      process.env.GITHUB_REPOSITORY,
      'branches',
      process.env.GITHUB_REF
    );

    // Verify environment variable was set
    expect(core.exportVariable).toHaveBeenCalledWith(
      'WORKING_DIRECTORY',
      expectedDir
    );

    // Verify output was set
    expect(core.setOutput).toHaveBeenCalledWith(
      'working-directory',
      expectedDir
    );
  });

  test('handles missing GitHub variables', async () => {
    // Remove required env variables
    delete process.env.GITHUB_REPOSITORY;
    delete process.env.GITHUB_REF;

    // Import the action
    const action = require('../src/index');

    // Run the action and expect it to fail
    await expect(action()).rejects.toThrow();

    // Verify failure was reported
    expect(core.setFailed).toHaveBeenCalled();
  });
});