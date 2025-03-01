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

# DIRECT EXECUTION APPROACH - No launcher script needed
log "Starting ElizaOS with Twitter plugin (direct execution)..."
cd /app/eliza/agent
log "Working directory: $(pwd)"
log "Directory contents: $(ls -la)"

# Start ElizaOS directly in the background
export NODE_OPTIONS="--no-warnings --experimental-specifier-resolution=node"
log "Starting ElizaOS with: npx ts-node --swc src/index.ts --isRoot --plugin twitter --autopost --debug"
npx ts-node --swc src/index.ts --isRoot --plugin twitter --autopost --debug &
ELIZA_PID=$!
log "ElizaOS started with PID $ELIZA_PID"

# Keep container alive
log "ElizaOS services running. Container will stay alive."
while true; do
    # Check if ElizaOS is still running
    if ! kill -0 $ELIZA_PID 2>/dev/null; then
        log "ElizaOS process died. Restarting..."
        cd /app/eliza/agent
        log "Restarting ElizaOS with: npx ts-node --swc src/index.ts --isRoot --plugin twitter --autopost --debug"
        npx ts-node --swc src/index.ts --isRoot --plugin twitter --autopost --debug &
        ELIZA_PID=$!
        log "ElizaOS restarted with PID $ELIZA_PID"
    fi
    sleep 30
done 