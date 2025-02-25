#!/bin/bash

# Build setup-working-directory action
cd setup-working-directory
npm install
npm run build

# Build init action
cd ../init
npm install
npm run build