#!/bin/bash

WORKING_DIRECTORY=$1
echo "WORKING_DIRECTORY:" $WORKING_DIRECTORY

BRANCHES_CACHE_FOLDER=${WORKING_DIRECTORY_PREFIX}/${GITHUB_REPOSITORY}/branches
FRAMEWORKS_CACHE_FOLDER=${WORKING_DIRECTORY_PREFIX}/${GITHUB_REPOSITORY}/cache

function getSlug {
  local name=$1
  # Step 1: Convert to lowercase
  local nameLower=$(echo "$name" | tr '[:upper:]' '[:lower:]')

  # Step 2: Replace all characters except 0-9 and a-z with a hyphen
  local slug=$(echo "$nameLower" | sed 's/[^a-z0-9]/-/g')

  # Step 3: Remove leading and trailing hyphens
  slug=$(echo "$slug" | sed 's/^-//' | sed 's/-$//')
  echo "$slug"
}

function getTargetBranchCacheFolderName {
  local targetBranchNameSlug=$(getSlug "$GITHUB_HEAD_REF")
  if [ -d "$WORKING_DIRECTORY/$SCHEDULED_VALIDATE_PREFIX$targetBranchNameSlug" ]; then
    echo "$WORKING_DIRECTORY/$SCHEDULED_VALIDATE_PREFIX$targetBranchNameSlug"
  else
    echo "$WORKING_DIRECTORY/$targetBranchNameSlug"
  fi
}

function initializeYarnCache {
  cd $WORKING_DIRECTORY

  local folder=$1
  local folderWithWorkingDirectory=$WORKING_DIRECTORY/$1

  # Check if yarn.lock exists
  if [ -f "$folderWithWorkingDirectory/yarn.lock" ]; then
    local yarnChecksum=yarn-$(sha1sum "$folderWithWorkingDirectory/yarn.lock" | awk '{print $1}')
    local yarnCacheFolder="$FRAMEWORKS_CACHE_FOLDER/$yarnChecksum"
  else
    echo "Warning: yarn.lock not found in $folderWithWorkingDirectory"
    local yarnCacheFolder="$FRAMEWORKS_CACHE_FOLDER/yarn-default"
    mkdir -p $yarnCacheFolder
  fi

  symlink_target=$(readlink "$folderWithWorkingDirectory/node_modules")

  if [ "$symlink_target" != "$yarnCacheFolder/node_modules" ]; then
    echo "yarn cache for ${folder:-"/"} is empty, initializing it..."
    cd $folderWithWorkingDirectory

    mkdir -p $yarnCacheFolder/node_modules
    ln -sfn $yarnCacheFolder/node_modules node_modules

    if [ "$folder" == "frontend" ]; then
      yarn decrypt-env
    fi
  else
    echo "yarn cache for ${folder:-"/"} is already present, skipping init."
  fi

  cd $folderWithWorkingDirectory
  
  # Check if package.json exists
  if [ -f "$folderWithWorkingDirectory/package.json" ]; then
    # If yarn.lock exists, use frozen-lockfile
    if [ -f "$folderWithWorkingDirectory/yarn.lock" ]; then
      yarn install --frozen-lockfile --no-progress --ignore-engines
    else
      # Without yarn.lock, we can't use frozen-lockfile
      echo "Installing dependencies without lockfile"
      yarn install --no-progress --ignore-engines
    fi
  else
    echo "Warning: package.json not found in $folderWithWorkingDirectory, skipping yarn install"
  fi

  echo "yarn cache for ${folder:-"/"} is stored in $yarnCacheFolder"
  echo "YARN_CACHE_USED_AT=$(date +%F)" > $yarnCacheFolder/$INIT_REPOSITORY_PIPELINE_ID_ENV_FILE
}

function initializeFrameworkCache {
  cd $WORKING_DIRECTORY

  local folder=$1
  local folderWithWorkingDirectory=$WORKING_DIRECTORY/$1
  local framework=$2
  if [ ! -d "$folderWithWorkingDirectory/$framework" ]; then
    if [ $GITHUB_HEAD_REF ]; then
      local targetBranchCacheFolder=$(getTargetBranchCacheFolderName)
      if [ -d "$targetBranchCacheFolder/$folder/$framework" ]; then
        echo "$framework cache for target branch $GITHUB_HEAD_REF in folder $folder exists, copying it..."
        cp -dpR "$targetBranchCacheFolder/$folder/$framework" "$folderWithWorkingDirectory/"
      fi
    else
      # Always create the $framework directory if it is not already present
      echo "$framework cache for $folder is empty, initializing it..."
      mkdir -p "$folderWithWorkingDirectory/$framework"
    fi
  else
    echo "$framework cache in folder $folder exists, skipping init..."
  fi
  if [ $framework = ".nx" ]; then
    cd $folderWithWorkingDirectory
    pwd
    if [ "$NX_RESET" == "true" ]; then
      echo "nx reset cache requested"
      yarn nx reset
    fi
  fi
}

initializeYarnCache
