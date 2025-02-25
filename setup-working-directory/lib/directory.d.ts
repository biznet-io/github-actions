import { WorkingDirectoryConfig } from './types';
export declare class DirectoryManager {
    private readonly config;
    constructor(config: WorkingDirectoryConfig);
    /**
     * Sanitize path to prevent path traversal
     */
    private sanitizePath;
    /**
     * Get the working directory path
     */
    getWorkingDirectoryPath(): string;
    /**
     * Create the working directory
     */
    createWorkingDirectory(): void;
}
