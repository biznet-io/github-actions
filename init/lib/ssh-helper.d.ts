import { GitEnvironment } from './types';
export declare class SSHHelper {
    private readonly config;
    constructor();
    /**
     * Initialize SSH configuration
     */
    initialize(): Promise<string>;
    /**
     * Setup SSH directory with proper permissions
     */
    private setupSSHDir;
    /**
     * Start SSH agent with custom socket
     */
    private startSSHAgent;
    /**
     * Configure known hosts file
     */
    private configureKnownHosts;
    /**
     * Add SSH key from environment variable
     */
    private addSSHKey;
    /**
     * Clean up SSH agent
     */
    cleanup(): Promise<void>;
    /**
     * Get environment variables for Git operations
     */
    getGitEnv(): GitEnvironment;
}
