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

# Create a simple wrapper script
log "Creating starter script for ElizaOS..."
cat > /app/eliza/agent/start-eliza.js << EOF
// ElizaOS starter script
// This will execute the TypeScript file with proper Node.js module settings
import { spawn } from 'child_process';
import { dirname } from 'path';
import { fileURLToPath } from 'url';

// Get current directory in ESM
const __dirname = dirname(fileURLToPath(import.meta.url));
console.log('Starting ElizaOS from directory:', __dirname);

// Configure process arguments
const args = [
  '--require=ts-node/register',
  '--loader=ts-node/esm',
  'src/index.ts',
  '--isRoot',
  '--plugin', 'twitter',
  '--autopost',
  '--debug'
];

console.log('Starting ElizaOS with arguments:', args.join(' '));

// Spawn node process with proper configuration
const proc = spawn('node', args, {
  cwd: __dirname,
  stdio: 'inherit',
  env: {
    ...process.env,
    NODE_OPTIONS: '--no-warnings',
    TS_NODE_PROJECT: './tsconfig.json'
  }
});

proc.on('error', (err) => {
  console.error('Failed to start ElizaOS:', err);
  process.exit(1);
});

proc.on('exit', (code) => {
  console.log('ElizaOS process exited with code:', code);
  process.exit(code || 0);
});
EOF

# Start ElizaOS using the wrapper script
log "Starting ElizaOS with Twitter plugin..."
cd /app/eliza/agent
log "Working directory: $(pwd)"
log "Directory contents: $(ls -la)"

# Start the wrapper script in the background
log "Starting ElizaOS with Node.js wrapper script"
node start-eliza.js &
ELIZA_PID=$!
log "ElizaOS started with PID $ELIZA_PID"

# Keep container alive
log "ElizaOS services running. Container will stay alive."
while true; do
    # Check if ElizaOS is still running
    if ! kill -0 $ELIZA_PID 2>/dev/null; then
        log "ElizaOS process died. Restarting..."
        cd /app/eliza/agent
        log "Restarting ElizaOS with Node.js wrapper script"
        node start-eliza.js &
        ELIZA_PID=$!
        log "ElizaOS restarted with PID $ELIZA_PID"
    fi
    sleep 30
done 