const core = require('@actions/core');
const exec = require('@actions/exec');
const io = require('@actions/io');
const SSHHelper = require('../src/ssh-helper');

// Mock dependencies
jest.mock('@actions/core');
jest.mock('@actions/exec');
jest.mock('@actions/io');

describe('SSHHelper', () => {
  let sshHelper;
  const mockSocketPath = '/tmp/mock-ssh-socket';

  beforeEach(() => {
    sshHelper = new SSHHelper();
    sshHelper.sshSocketPath = mockSocketPath;
    process.env.SSH_PRIVATE_KEY = 'mock-key';
  });

  afterEach(() => {
    jest.clearAllMocks();
    delete process.env.SSH_PRIVATE_KEY;
  });

  test('initializes SSH configuration', async () => {
    await sshHelper.initialize();

    // Verify SSH directory was created
    expect(io.mkdirP).toHaveBeenCalled();

    // Verify SSH agent was started
    expect(exec.exec).toHaveBeenCalledWith(
      'ssh-agent',
      ['-a', mockSocketPath]
    );

    // Verify known hosts were configured
    expect(exec.exec).toHaveBeenCalledWith(
      'ssh-keyscan',
      ['-H', 'github.com'],
      expect.any(Object)
    );

    // Verify SSH key was added
    expect(exec.exec).toHaveBeenCalledWith(
      'ssh-add',
      ['-'],
      expect.any(Object)
    );
  });

  test('handles missing SSH key', async () => {
    delete process.env.SSH_PRIVATE_KEY;

    await expect(sshHelper.initialize()).rejects.toThrow(
      'SSH_PRIVATE_KEY secret is not set'
    );
  });

  test('performs cleanup', async () => {
    await sshHelper.cleanup();

    // Verify SSH identities were removed
    expect(exec.exec).toHaveBeenCalledWith(
      'ssh-add',
      ['-D'],
      expect.any(Object)
    );
  });

  test('provides git environment', () => {
    const env = sshHelper.getGitEnv();

    expect(env).toEqual({
      SSH_AUTH_SOCK: mockSocketPath,
      GIT_SSH_COMMAND: 'ssh -o StrictHostKeyChecking=yes'
    });
  });
});