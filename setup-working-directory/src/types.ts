export interface ActionInputs {
  path: string
}

export interface WorkingDirectoryConfig {
  basePath: string
  repository: string
  ref: string
}

export interface ActionOutputs {
  workingDirectory: string
}
