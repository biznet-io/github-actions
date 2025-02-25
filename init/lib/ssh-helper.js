"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.SSHHelper = void 0;
const core = __importStar(require("@actions/core"));
const exec = __importStar(require("@actions/exec"));
const io = __importStar(require("@actions/io"));
const path = __importStar(require("path"));
const os = __importStar(require("os"));
const fs = __importStar(require("fs/promises"));
const crypto = __importStar(require("crypto"));
class SSHHelper {
    constructor() {
        this.config = {
            sshSocketPath: path.join(os.tmpdir(), `ssh-auth-sock-${crypto.randomBytes(6).toString('hex')}`),
            sshDir: path.join(os.homedir(), '.ssh'),
            knownHostsFile: path.join(os.homedir(), '.ssh', 'known_hosts')
        };
    }
    /**
     * Initialize SSH configuration
     */
    async initialize() {
        try {
            core.debug('Initializing SSH configuration');
            await this.setupSSHDir();
            await this.startSSHAgent();
            await this.configureKnownHosts();
            await this.addSSHKey();
            core.debug('SSH configuration completed successfully');
            return this.config.sshSocketPath;
        }
        catch (error) {
            throw new Error(`SSH initialization failed: ${error.message}`);
        }
    }
    /**
     * Setup SSH directory with proper permissions
     */
    async setupSSHDir() {
        try {
            core.debug(`Creating SSH directory: ${this.config.sshDir}`);
            await io.mkdirP(this.config.sshDir);
            await fs.chmod(this.config.sshDir, 0o700);
        }
        catch (error) {
            throw new Error(`Failed to setup SSH directory: ${error.message}`);
        }
    }
    /**
     * Start SSH agent with custom socket
     */
    async startSSHAgent() {
        try {
            core.debug(`Starting SSH agent with socket: ${this.config.sshSocketPath}`);
            await exec.exec('ssh-agent', ['-a', this.config.sshSocketPath]);
        }
        catch (error) {
            throw new Error(`Failed to start SSH agent: ${error.message}`);
        }
    }
    /**
     * Configure known hosts file
     */
    async configureKnownHosts() {
        try {
            core.debug('Configuring known hosts');
            await exec.exec('ssh-keyscan', ['-H', 'github.com'], {
                outFile: this.config.knownHostsFile
            });
            await fs.chmod(this.config.knownHostsFile, 0o600);
        }
        catch (error) {
            throw new Error(`Failed to configure known hosts: ${error.message}`);
        }
    }
    /**
     * Add SSH key from environment variable
     */
    async addSSHKey() {
        const sshKey = process.env['SSH_PRIVATE_KEY'];
        if (!sshKey) {
            throw new Error('SSH_PRIVATE_KEY secret is not set');
        }
        try {
            core.debug('Adding SSH key');
            await exec.exec('ssh-add', ['-'], {
                env: { SSH_AUTH_SOCK: this.config.sshSocketPath },
                input: Buffer.from(sshKey)
            });
        }
        catch (error) {
            throw new Error(`Failed to add SSH key: ${error.message}`);
        }
    }
    /**
     * Clean up SSH agent
     */
    async cleanup() {
        try {
            core.debug('Cleaning up SSH configuration');
            await exec.exec('ssh-add', ['-D'], {
                env: { SSH_AUTH_SOCK: this.config.sshSocketPath }
            });
        }
        catch (error) {
            core.warning(`SSH cleanup failed: ${error.message}`);
        }
    }
    /**
     * Get environment variables for Git operations
     */
    getGitEnv() {
        return {
            SSH_AUTH_SOCK: this.config.sshSocketPath,
            GIT_SSH_COMMAND: 'ssh -o StrictHostKeyChecking=yes'
        };
    }
}
exports.SSHHelper = SSHHelper;
//# sourceMappingURL=ssh-helper.js.map