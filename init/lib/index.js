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
const core = __importStar(require("@actions/core"));
const io = __importStar(require("@actions/io"));
const ssh_helper_1 = require("./ssh-helper");
const git_helper_1 = require("./git-helper");
async function getInputs() {
    return {
        WORKING_DIRECTORY: core.getInput('WORKING_DIRECTORY', { required: true })
    };
}
async function run() {
    let sshHelper;
    try {
        core.debug('Starting repository initialization');
        // Get and validate inputs
        const inputs = await getInputs();
        // Create and change to working directory
        core.debug(`Setting up working directory: ${inputs.WORKING_DIRECTORY}`);
        await io.mkdirP(inputs.WORKING_DIRECTORY);
        process.chdir(inputs.WORKING_DIRECTORY);
        core.info(`Working directory: ${inputs.WORKING_DIRECTORY}`);
        // Initialize SSH
        sshHelper = new ssh_helper_1.SSHHelper();
        await sshHelper.initialize();
        core.info('SSH configuration completed');
        // Initialize Git operations
        const gitHelper = new git_helper_1.GitHelper(inputs.WORKING_DIRECTORY, sshHelper);
        await gitHelper.configureGit();
        core.info('Git configuration completed');
        // Handle repository cache and setup
        await gitHelper.handleCache();
        core.info('Repository cache handled');
        // Handle pull request merge if needed
        await gitHelper.handlePullRequestMerge();
        core.info('Repository initialization completed successfully');
    }
    catch (error) {
        core.setFailed(`Action failed: ${error.message}`);
        throw error;
    }
    finally {
        // Cleanup SSH if initialized
        if (sshHelper) {
            try {
                await sshHelper.cleanup();
                core.debug('SSH cleanup completed');
            }
            catch (error) {
                core.warning(`SSH cleanup failed: ${error.message}`);
            }
        }
    }
}
// Run the action
if (require.main === module) {
    run().catch(error => {
        core.setFailed(error.message);
    });
}
//# sourceMappingURL=index.js.map