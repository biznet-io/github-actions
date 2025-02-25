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
const config_1 = require("./config");
const directory_1 = require("./directory");
async function run() {
    try {
        core.debug('Starting setup-working-directory action');
        // Get inputs and configuration
        const inputs = (0, config_1.getInputs)();
        const config = (0, config_1.getConfig)(inputs);
        // Create directory manager
        const directoryManager = new directory_1.DirectoryManager(config);
        // Create working directory
        directoryManager.createWorkingDirectory();
        // Get the working directory path
        const workingDirectory = directoryManager.getWorkingDirectoryPath();
        core.debug(`Working directory path: ${workingDirectory}`);
        // Set outputs
        core.info(`Setting WORKING_DIRECTORY: ${workingDirectory}`);
        core.exportVariable('WORKING_DIRECTORY', workingDirectory);
        core.setOutput('working-directory', workingDirectory);
        core.debug('Setup working directory completed successfully');
    }
    catch (error) {
        core.setFailed(`Action failed: ${error.message}`);
        throw error;
    }
}
// Run the action
if (require.main === module) {
    run().catch(error => {
        core.setFailed(error.message);
    });
}
//# sourceMappingURL=index.js.map