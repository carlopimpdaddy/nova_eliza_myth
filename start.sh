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

log "Starting ElizaOS server and client components..."
cd /app/eliza/agent
log "Working directory: $(pwd)"
log "Directory contents: $(ls -la)"

# Start ElizaOS server (background)
log "Starting ElizaOS server with Twitter plugin..."
export NODE_OPTIONS="--no-warnings --experimental-specifier-resolution=node"
export TWITTER_ENABLED=true
export TWITTER_AUTOPOST=true
export TWITTER_AUTOPOST_INTERVAL=${TWITTER_AUTOPOST_INTERVAL:-60}

# Run the server component (pnpm start) in the background
log "Running: pnpm start -- --isRoot --plugin twitter --autopost --debug"
pnpm start -- --isRoot --plugin twitter --autopost --debug &
SERVER_PID=$!
log "ElizaOS server started with PID $SERVER_PID"

# Give server a moment to initialize before starting client
sleep 5

# Start the client component (pnpm start:client) in the background
log "Running: pnpm start:client"
pnpm start:client &
CLIENT_PID=$!
log "ElizaOS client started with PID $CLIENT_PID"

# Keep container alive and monitor both processes
log "ElizaOS services running. Container will stay alive."
while true; do
    # Check if server is still running
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        log "ElizaOS server died. Restarting..."
        pnpm start -- --isRoot --plugin twitter --autopost --debug &
        SERVER_PID=$!
        log "ElizaOS server restarted with PID $SERVER_PID"
    fi
    
    # Check if client is still running
    if ! kill -0 $CLIENT_PID 2>/dev/null; then
        log "ElizaOS client died. Restarting..."
        pnpm start:client &
        CLIENT_PID=$!
        log "ElizaOS client restarted with PID $CLIENT_PID"
    fi
    
    sleep 30
done 