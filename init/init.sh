#!/bin/bash

WORKING_DIRECTORY=$1
mkdir -p $WORKING_DIRECTORY
cd $WORKING_DIRECTORY
echo "WORKING_DIRECTORY:" $WORKING_DIRECTORY
# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "SCRIPT_DIR:" $SCRIPT_DIR

# Create unique, secure socket
SSH_SOCK=$(mktemp -u)

# Start SSH agent with unique socket
ssh-agent -a "$SSH_SOCK" > /dev/null

# Configure strict SSH settings
mkdir -p ~/.ssh
ssh-keyscan -H github.com >> ~/.ssh/known_hosts

# Add SSH key with strict permissions
SSH_AUTH_SOCK="$SSH_SOCK" ssh-add - <<< "${SSH_PRIVATE_KEY}"

echo "Init repo"
git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
git config --global user.name "${GITHUB_ACTOR}"
git config --global init.defaultBranch "${GITHUB_HEAD_REF}"
export GIT_DISCOVERY_ACROSS_FILESYSTEM=true

if [ -f "$WORKING_DIRECTORY/$INIT_REPOSITORY_PIPELINE_ID_ENV_FILE" ]; then
  source $WORKING_DIRECTORY/$INIT_REPOSITORY_PIPELINE_ID_ENV_FILE
  if [ $INIT_REPOSITORY_PIPELINE_ID == $GITHUB_RUN_ID ]; then
    echo "Job has been manually re-run, removing repository cache"
    cd $WORKING_DIRECTORY/..
    rm -Rf $WORKING_DIRECTORY/
    mkdir -p $WORKING_DIRECTORY
    cd $WORKING_DIRECTORY
  else
    echo "Job has been automatically executed, keeping repository cache"
  fi
else
  echo "No init repository pipeline id variable found"
fi

if [ "$(git remote | grep origin)" != "origin" ]; then
  echo 'repository cache is empty, initializing it...'
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git clone --depth 1 --branch "$GITHUB_HEAD_REF"  git@github.com:${GITHUB_REPOSITORY}.git .

  git config merge.directoryRenames false
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git fetch --tags --force
else
  echo 'repository cache is already present, updating sources...'
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git fetch --tags --force
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git reset --hard $GITHUB_HEAD_REF
fi

echo "INIT_REPOSITORY_PIPELINE_ID=$GITHUB_RUN_ID" > $WORKING_DIRECTORY/$INIT_REPOSITORY_PIPELINE_ID_ENV_FILE

### For Pull Request workflows in GitHub Actions, we need to test the merge result
### This is similar to GitLab's merged results pipelines
if [ $GITHUB_BASE_REF ]; then

  # Git fetch the target branch to allow nx making the diff
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git fetch origin $GITHUB_BASE_REF:refs/remotes/origin/$GITHUB_BASE_REF

  # Extract PR number from GITHUB_REF (format: refs/pull/NUMBER/merge)
  PR_NUMBER=$(echo $GITHUB_REF | sed 's/refs\/pull\/\([0-9]*\)\/merge/\1/')

  # Fetch the PR merge reference
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git fetch origin pull/$PR_NUMBER/merge:pr-merge

  # Check out the merge reference to be sure to test over it
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git checkout pr-merge

fi

# Call init-cache.sh with the absolute path and pass working directory
"$SCRIPT_DIR/init-cache.sh" "$WORKING_DIRECTORY"

# Immediately delete all identities
#SSH_AUTH_SOCK="$SSH_SOCK" ssh-add -D
