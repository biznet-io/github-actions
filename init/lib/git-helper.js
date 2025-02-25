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
exports.GitHelper = void 0;
const core = __importStar(require("@actions/core"));
const exec = __importStar(require("@actions/exec"));
const io = __importStar(require("@actions/io"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs/promises"));
class GitHelper {
    constructor(workingDirectory, sshHelper) {
        const repository = process.env['GITHUB_REPOSITORY'];
        const sha = process.env['GITHUB_SHA'];
        const actor = process.env['GITHUB_ACTOR'];
        const ref = process.env['GITHUB_REF'];
        const baseRef = process.env['GITHUB_BASE_REF'];
        const runId = process.env['GITHUB_RUN_ID'];
        const pipelineIdFile = process.env['INIT_REPOSITORY_PIPELINE_ID_ENV_FILE'];
        if (!repository || !sha || !actor || !ref || !runId || !pipelineIdFile) {
            throw new Error('Required environment variables are not set');
        }
        this.config = { repository, sha, actor, ref, baseRef, runId };
        this.sshHelper = sshHelper;
        this.cacheConfig = {
            workingDirectory,
            pipelineIdFile,
            runId
        };
    }
    /**
     * Configure global git settings
     */
    async configureGit() {
        try {
            core.debug('Configuring git globals');
            await exec.exec('git', ['config', '--global', 'user.email', `${this.config.actor}@users.noreply.github.com`]);
            await exec.exec('git', ['config', '--global', 'user.name', this.config.actor]);
            await exec.exec('git', ['config', '--global', 'init.defaultBranch', this.config.ref]);
            process.env['GIT_DISCOVERY_ACROSS_FILESYSTEM'] = 'true';
        }
        catch (error) {
            throw new Error(`Git configuration failed: ${error.message}`);
        }
    }
    /**
     * Check if repository has remote origin
     */
    async hasRemoteOrigin() {
        try {
            const { exitCode } = await exec.getExecOutput('git', ['remote'], {
                silent: true,
                ignoreReturnCode: true
            });
            return exitCode === 0;
        }
        catch (error) {
            return false;
        }
    }
    /**
     * Clone repository
     */
    async cloneRepository() {
        try {
            core.debug('Cloning repository');
            await exec.exec('git', [
                'clone',
                '--depth', '1',
                '--branch', this.config.sha,
                `git@github.com:${this.config.repository}.git`,
                '.'
            ], { env: this.sshHelper.getGitEnv() });
            await exec.exec('git', ['config', 'merge.directoryRenames', 'false']);
            await exec.exec('git', ['fetch', '--tags', '--force'], { env: this.sshHelper.getGitEnv() });
        }
        catch (error) {
            throw new Error(`Repository clone failed: ${error.message}`);
        }
    }
    /**
     * Update existing repository
     */
    async updateRepository() {
        try {
            core.debug('Updating repository');
            await exec.exec('git', ['fetch', '--tags', '--force'], { env: this.sshHelper.getGitEnv() });
            await exec.exec('git', ['reset', '--hard', this.config.sha], { env: this.sshHelper.getGitEnv() });
        }
        catch (error) {
            throw new Error(`Repository update failed: ${error.message}`);
        }
    }
    /**
     * Handle repository cache
     */
    async handleCache() {
        try {
            const envFilePath = path.join(this.cacheConfig.workingDirectory, this.cacheConfig.pipelineIdFile);
            let previousRunId;
            try {
                const envContent = await fs.readFile(envFilePath, 'utf8');
                previousRunId = envContent?.split('=')[1]?.trim();
                core.debug(`Previous run ID: ${previousRunId}`);
            }
            catch (error) {
                core.debug('No previous run ID found');
            }
            if (previousRunId === this.cacheConfig.runId) {
                core.info('Job has been manually re-run, removing repository cache');
                await io.rmRF(this.cacheConfig.workingDirectory);
                await io.mkdirP(this.cacheConfig.workingDirectory);
            }
            const hasOrigin = await this.hasRemoteOrigin();
            if (!hasOrigin) {
                await this.cloneRepository();
            }
            else {
                await this.updateRepository();
            }
            await fs.writeFile(envFilePath, `INIT_REPOSITORY_PIPELINE_ID=${this.cacheConfig.runId}`);
        }
        catch (error) {
            throw new Error(`Cache handling failed: ${error.message}`);
        }
    }
    /**
     * Handle merge result pipeline for pull requests
     */
    async handlePullRequestMerge() {
        if (!this.config.baseRef) {
            core.debug('Not a pull request, skipping merge handling');
            return;
        }
        try {
            core.debug(`Handling pull request merge with base ref: ${this.config.baseRef}`);
            // Implementation for merge result pipeline would go here
            // This would replicate the functionality from init-merge-result-pipeline.sh
        }
        catch (error) {
            throw new Error(`Pull request merge handling failed: ${error.message}`);
        }
    }
}
exports.GitHelper = GitHelper;
//# sourceMappingURL=git-helper.js.map