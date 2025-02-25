import * as exec from '@actions/exec';
import * as io from '@actions/io';
import { SSHHelper } from '../ssh-helper';

// Mock dependencies
jest.mock('@actions/core');
jest.mock('@actions/exec');
jest.mock('@actions/io');

describe('SSHHelper', () => {
  let sshHelper: SSHHelper;
  const mockSocketPath = '/tmp/mock-ssh-socket';

  beforeEach(() => {
    sshHelper = new SSHHelper();
    // @ts-expect-error Accessing private config for testing
    sshHelper.config.sshSocketPath = mockSocketPath;
    process.env['SSH_PRIVATE_KEY'] = 'mock-key';
  });

  afterEach(() => {
    jest.clearAllMocks();
    delete process.env['SSH_PRIVATE_KEY'];
  });

  it('initializes SSH configuration', async () => {
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

  it('handles missing SSH key', async () => {
    delete process.env['SSH_PRIVATE_KEY'];

    await expect(sshHelper.initialize()).rejects.toThrow(
      'SSH_PRIVATE_KEY secret is not set'
    );
  });

  it('performs cleanup', async () => {
    await sshHelper.cleanup();

    // Verify SSH identities were removed
    expect(exec.exec).toHaveBeenCalledWith(
      'ssh-add',
      ['-D'],
      expect.any(Object)
    );
  });

  it('provides git environment', () => {
    const env = sshHelper.getGitEnv();

    expect(env).toEqual({
      SSH_AUTH_SOCK: mockSocketPath,
      GIT_SSH_COMMAND: 'ssh -o StrictHostKeyChecking=yes'
    });
  });
});
