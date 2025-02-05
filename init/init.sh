#!/bin/bash

WORKING_DIRECTORY=$1
mkdir -p $WORKING_DIRECTORY
cd $WORKING_DIRECTORY
echo "WORKING_DIRECTORY:" $WORKING_DIRECTORY

# Create unique, secure socket
SSH_SOCK=$(mktemp -u)

# Start SSH agent with unique socket
ssh-agent -a "$SSH_SOCK" > /dev/null

# Configure strict SSH settings
mkdir -p ~/.ssh
ssh-keyscan -H github.com >> ~/.ssh/known_hosts

# Add SSH key with strict permissions
SSH_AUTH_SOCK="$SSH_SOCK" ssh-add - <<< "${{ secrets.SSH_PRIVATE_KEY }}"

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

  # Clone repository using SSH
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git clone git@github.com:${GITHUB_REPOSITORY}.git -b "${GITHUB_HEAD_REF}" .

  git config merge.directoryRenames false
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git fetch --tags --force
else
  echo 'repository cache is already present, updating sources...'
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git fetch --tags --force
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git reset --hard origin/$GITHUB_HEAD_REF
fi

echo "INIT_REPOSITORY_PIPELINE_ID=$GITHUB_RUN_ID" > $WORKING_DIRECTORY/$INIT_REPOSITORY_PIPELINE_ID_ENV_FILE

### For Pull Request workflows in GitHub Actions, we need to test the merge result
### This is similar to GitLab's merged results pipelines
if [ $GITHUB_BASE_REF ]; then
  echo "Merge $GITHUB_BASE_REF into $WORKING_DIRECTORY to allow a merge result pipeline"

  # attempt to merge
  SSH_AUTH_SOCK="$SSH_SOCK" GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=yes" git merge --no-commit --no-ff origin/$GITHUB_BASE_REF

  # if merge conflict detected
  if [ $? -ne 0 ]; then
    echo "################################################################################################"
    echo "################################################################################################"
    echo "################################################################################################"
    echo ""
    echo "Merge conflict detected:"
    echo "Resolve them by merging $GITHUB_BASE_REF into $GITHUB_HEAD_REF and push changes."
    echo ""
    echo "################################################################################################"
    echo "################################################################################################"
    echo "################################################################################################"

    echo "Resetting and make the pipeline fail to handle conflicts..."

    git merge --abort

    echo "Add a comment to PR to notify assignee"
  ADD_THREAD=$(curl --fail --output "/dev/null" --silent --show-error --write-out "HTTP response: ${http_code}\n\n" \
    --data "{\"body\": \" :warning: Conflicts detected, resolve them by merging \`${GITHUB_BASE_REF}\` into \`${GITHUB_HEAD_REF}\` and then push changes.\"}" \
    --header "Content-Type: application/json" \
    --header "Authorization: token $GITHUB_TOKEN" \
    --request POST \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/issues/${GITHUB_EVENT_NUMBER}/comments")

    exit 1
  else
    echo "No conflicts, continue pull request pipeline"
  fi
fi

### Never init cache for tag pipelines that are only triggered to promote a rc tag to a release tag
if [ "$GITHUB_REF_TYPE" != "tag" ]; then
  ./init-cache.sh
fi

# Immediately delete all identities
SSH_AUTH_SOCK="$SSH_SOCK" ssh-add -D
