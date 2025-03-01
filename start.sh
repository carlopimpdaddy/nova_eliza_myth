#!/bin/bash

# Skip error exit to ensure we continue even if commands fail
set +e

# Log function for better visibility
log() {
    echo "$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ") $1"
}

log "Starting ElizaOS deployment..."

# Set up Twitter variables
log "Setting up Twitter variables..."

# Map Twitter credentials from Railway environment variables if needed
if [ -n "$TWITTER_API_SECRET_KEY" ] && [ -z "$TWITTER_API_SECRET" ]; then
    export TWITTER_API_SECRET="$TWITTER_API_SECRET_KEY"
    log "Set TWITTER_API_SECRET from TWITTER_API_SECRET_KEY"
fi

if [ -n "$TWITTER_ACCESS_TOKEN_SECRET" ] && [ -z "$TWITTER_ACCESS_SECRET" ]; then
    export TWITTER_ACCESS_SECRET="$TWITTER_ACCESS_TOKEN_SECRET"
    log "Set TWITTER_ACCESS_SECRET from TWITTER_ACCESS_TOKEN_SECRET"
fi

# Log Twitter environment variables
log "TWITTER ENVIRONMENT VARIABLES (after mapping):"
log "TWITTER_API_KEY=$TWITTER_API_KEY"
log "TWITTER_API_SECRET=$TWITTER_API_SECRET"
log "TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN"
log "TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET"

# Create .env file with Twitter credentials
log "Creating .env files with Twitter configuration..."

cat > /app/.env << EOF
TWITTER_API_KEY=$TWITTER_API_KEY
TWITTER_API_SECRET=$TWITTER_API_SECRET
TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN
TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET
TWITTER_ENABLED=true
TWITTER_AUTOPOST=true
TWITTER_AUTOPOST_INTERVAL=${TWITTER_AUTOPOST_INTERVAL:-60}
EOF

# Copy .env to the agent directory
cp /app/.env /app/eliza/agent/.env
log "Copied .env to agent directory"

# Create a simple CommonJS loader for TypeScript (using .cjs extension)
log "Creating a TypeScript loader..."
cat > /app/eliza/agent/loader.cjs << EOF
// Simple CommonJS loader for TypeScript
require('ts-node').register({
  transpileOnly: true,
  skipProject: true,
  compilerOptions: {
    module: 'commonjs',
    esModuleInterop: true,
    target: 'es2020'
  }
});

// Set command line arguments
process.argv = [
  process.argv[0],
  process.argv[1],
  '--isRoot',
  '--plugin', 'twitter',
  '--autopost',
  '--debug'
];

// Load the TypeScript file
try {
  require('./src/index.ts');
  console.log('Successfully loaded ElizaOS via CommonJS loader');
} catch (err) {
  console.error('Error loading ElizaOS:', err);
  process.exit(1);
}
EOF

# Start ElizaOS using the JS loader with CJS extension
log "Starting ElizaOS with Twitter plugin via CommonJS loader..."
cd /app/eliza/agent
export NODE_OPTIONS="--no-warnings"
node loader.cjs &
ELIZA_PID=$!
log "ElizaOS started with PID $ELIZA_PID"

# Keep container alive
log "ElizaOS services running. Container will stay alive."
while true; do
    # Check if ElizaOS is still running
    if ! kill -0 $ELIZA_PID 2>/dev/null; then
        log "ElizaOS process died. Restarting..."
        cd /app/eliza/agent
        node loader.cjs &
        ELIZA_PID=$!
        log "ElizaOS restarted with PID $ELIZA_PID"
    fi
    sleep 30
done 