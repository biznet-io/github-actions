import { DirectoryManager } from '../directory';
import { WorkingDirectoryConfig } from '../types';
import * as fs from 'fs';

jest.mock('fs');

describe('DirectoryManager', () => {
  const mockConfig: WorkingDirectoryConfig = {
    basePath: '/base/path',
    repository: 'owner/repo',
    ref: 'refs/heads/main',
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should create working directory path correctly', () => {
    const manager = new DirectoryManager(mockConfig);
    const path = manager.getWorkingDirectoryPath();
    expect(path).toBe('/base/path/owner/repo/branches/refs/heads/main');
  });

  it('should sanitize path traversal attempts', () => {
    const maliciousConfig: WorkingDirectoryConfig = {
      ...mockConfig,
      basePath: '../../../etc',
    };
    const manager = new DirectoryManager(maliciousConfig);
    const path = manager.getWorkingDirectoryPath();
    expect(path).not.toContain('../');
  });

  it('should create directory with recursive option', () => {
    const manager = new DirectoryManager(mockConfig);
    manager.createWorkingDirectory();
    expect(fs.mkdirSync).toHaveBeenCalledWith(
      expect.any(String),
      { recursive: true }
    );
  });

  it('should throw error when directory creation fails', () => {
    (fs.mkdirSync as jest.Mock).mockImplementation(() => {
      throw new Error('Permission denied');
    });

    const manager = new DirectoryManager(mockConfig);
    expect(() => manager.createWorkingDirectory()).toThrow('Failed to create working directory');
  });
});