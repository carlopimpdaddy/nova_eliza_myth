#!/bin/sh
cd /app/eliza/agent
export NODE_OPTIONS="--no-warnings"
npx ts-node src/index.ts --isRoot --plugin twitter --autopost --debug 