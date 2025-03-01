#!/bin/sh
cd /app/eliza/agent
export NODE_OPTIONS="--no-warnings"
# Use a more explicit ts-node command with proper flags for ESM support
npx ts-node --esm --transpile-only --skip-project src/index.ts --isRoot --plugin twitter --autopost --debug 