export interface ActionInputs {
  WORKING_DIRECTORY: string
}
export interface GitConfig {
  repository: string
  sha: string
  actor: string
  ref: string
  baseRef?: string | undefined
  runId: string
}
export interface SSHConfig {
  sshSocketPath: string
  sshDir: string
  knownHostsFile: string
}
export interface GitEnvironment {
  SSH_AUTH_SOCK: string
  GIT_SSH_COMMAND: string
  [key: string]: string
}
export interface RepositoryCacheConfig {
  workingDirectory: string
  pipelineIdFile: string
  runId: string
}
