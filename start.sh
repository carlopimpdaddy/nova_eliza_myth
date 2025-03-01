#!/bin/bash
set -e

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

# Check if all Twitter credentials are present
if [ -n "$TWITTER_API_KEY" ] && [ -n "$TWITTER_API_SECRET" ] && 
   [ -n "$TWITTER_ACCESS_TOKEN" ] && [ -n "$TWITTER_ACCESS_SECRET" ]; then
    log "All Twitter credentials present, setting up Twitter integration"
    
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
    
    # Compile TypeScript files if they haven't been compiled
    if [ ! -f "/app/eliza/agent/dist/index.js" ]; then
        log "Compiled JavaScript not found. Attempting to compile TypeScript..."
        cd /app/eliza/agent
        npx tsc --skipLibCheck || echo "TypeScript compilation warning (continuing)"
    fi
    
    # Start the ElizaOS process
    log "Starting ElizaOS with Twitter plugin using custom launcher..."
    node /app/agent/dist/index.js &
    
    # Store the PID of the ElizaOS process
    ELIZA_PID=$!
    log "ElizaOS started with PID $ELIZA_PID"
else
    log "WARNING: Twitter credentials missing. Twitter integration will not be enabled."
fi

# Start the health check server
log "Starting health check server on port 8080..."
node /app/health-server.js &

log "ElizaOS services running. Container will stay alive."

# Wait for signals to properly terminate child processes
cleanup() {
    log "Received termination signal. Cleaning up..."
    # Kill child processes
    pkill -P $$ || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Keep the container alive
while true; do
    # Check if ElizaOS is still running
    if [ -n "$ELIZA_PID" ] && ! kill -0 $ELIZA_PID 2>/dev/null; then
        log "ElizaOS process died. Restarting..."
        node /app/agent/dist/index.js &
        ELIZA_PID=$!
        log "ElizaOS restarted with PID $ELIZA_PID"
    fi
    
    sleep 10
done 