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
SERVER_PORT=3000
EOF

# Copy .env to the agent directory
cp /app/.env /app/eliza/agent/.env
log "Copied .env to agent directory"

# Create a tsconfig.json file to help ts-node understand ES modules
log "Creating a tsconfig.json file for ts-node..."
cat > /app/eliza/agent/tsconfig.json << EOF
{
  "compilerOptions": {
    "target": "es2020",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "resolveJsonModule": true,
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "ts-node": {
    "esm": true,
    "transpileOnly": true,
    "swc": true,
    "experimentalSpecifierResolution": "node"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules"]
}
EOF

log "Starting ElizaOS server component..."
cd /app/eliza/agent
log "Working directory: $(pwd)"
log "Directory contents: $(ls -la)"
log "Available npm scripts:"
pnpm run --list || log "Could not list available scripts"

# Set up environment variables
export NODE_OPTIONS="--no-warnings --experimental-specifier-resolution=node"
export TWITTER_ENABLED=true
export TWITTER_AUTOPOST=true
export TWITTER_AUTOPOST_INTERVAL=${TWITTER_AUTOPOST_INTERVAL:-60}
export SERVER_PORT=3000
export HEADLESS=true  # Run in headless mode (no UI needed)
export ENABLE_AUTO_RUN=true  # Enable auto-running features

# Run ElizaOS using the only available command
log "Running: pnpm start -- --isRoot --plugin twitter --autopost --debug"
pnpm start -- --isRoot --plugin twitter --autopost --debug &
SERVER_PID=$!
log "ElizaOS server started with PID $SERVER_PID"

# Keep container alive and monitor the process
log "ElizaOS service running. Container will stay alive."
while true; do
    # Check if server is still running
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        log "ElizaOS server died. Restarting..."
        pnpm start -- --isRoot --plugin twitter --autopost --debug &
        SERVER_PID=$!
        log "ElizaOS server restarted with PID $SERVER_PID"
    fi
    
    sleep 30
done 