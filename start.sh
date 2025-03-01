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

# Create a direct launch script
log "Creating a direct launch script..."
cat > /app/eliza/agent/direct-launch.js << EOF
// Direct launcher script for ElizaOS with Twitter
import { spawn } from 'child_process';
import { writeFileSync } from 'fs';
import { dirname } from 'path';
import { fileURLToPath } from 'url';

// Get current directory in ESM
const __dirname = dirname(fileURLToPath(import.meta.url));
console.log('[LAUNCHER] Starting from directory:', __dirname);

// Create a minimal package.json override for the client
try {
  const clientPackageOverride = {
    "name": "fake-client",
    "scripts": {
      "start": "echo Client placeholder"
    }
  };
  writeFileSync(__dirname + '/client/package.json', JSON.stringify(clientPackageOverride, null, 2));
  console.log('[LAUNCHER] Created placeholder client package.json');
} catch (err) {
  console.log('[LAUNCHER] Warning: Could not create client placeholder:', err.message);
}

// Start the ElizaOS process directly
console.log('[LAUNCHER] Starting ElizaOS with Twitter plugin...');
const args = [
  '--loader=ts-node/esm',
  'src/index.ts',
  '--isRoot',
  '--plugin', 'twitter',
  '--autopost',
  '--debug'
];

console.log('[LAUNCHER] Command: node', args.join(' '));

// Force Twitter plugin to load by setting explicit environment variables
process.env.TWITTER_ENABLED = 'true';
process.env.TWITTER_AUTOPOST = 'true';
process.env.TWITTER_DEBUG = 'true';
process.env.HEADLESS = 'true';
process.env.ENABLE_AUTO_RUN = 'true';

console.log('[LAUNCHER] Twitter environment variables:');
console.log('- TWITTER_API_KEY:', process.env.TWITTER_API_KEY ? '✓ Set' : '✗ Missing');
console.log('- TWITTER_API_SECRET:', process.env.TWITTER_API_SECRET ? '✓ Set' : '✗ Missing');
console.log('- TWITTER_ACCESS_TOKEN:', process.env.TWITTER_ACCESS_TOKEN ? '✓ Set' : '✗ Missing');
console.log('- TWITTER_ACCESS_SECRET:', process.env.TWITTER_ACCESS_SECRET ? '✓ Set' : '✗ Missing');
console.log('- TWITTER_ENABLED:', process.env.TWITTER_ENABLED);
console.log('- TWITTER_AUTOPOST:', process.env.TWITTER_AUTOPOST);
console.log('- TWITTER_AUTOPOST_INTERVAL:', process.env.TWITTER_AUTOPOST_INTERVAL);

// Execute ElizaOS directly
const elizaProcess = spawn('node', args, {
  cwd: __dirname,
  stdio: 'inherit',
  env: process.env
});

elizaProcess.on('exit', (code) => {
  console.log('[LAUNCHER] ElizaOS exited with code:', code);
  process.exit(code || 0);
});
EOF

log "Setting up environment variables..."
# Set up environment variables and force them for child processes
export NODE_OPTIONS="--no-warnings --experimental-specifier-resolution=node"
export TWITTER_ENABLED=true
export TWITTER_AUTOPOST=true
export TWITTER_DEBUG=true
export TWITTER_AUTOPOST_INTERVAL=${TWITTER_AUTOPOST_INTERVAL:-60}
export SERVER_PORT=3000
export HEADLESS=true
export ENABLE_AUTO_RUN=true

log "Starting ElizaOS with direct launcher..."
cd /app/eliza/agent
log "Working directory: $(pwd)"

# Run ElizaOS using our direct launcher
log "Running direct launcher for ElizaOS with Twitter"
node direct-launch.js &
SERVER_PID=$!
log "ElizaOS direct launcher started with PID $SERVER_PID"

# Keep container alive and monitor the process
log "ElizaOS service running. Container will stay alive."
while true; do
    # Check if server is still running
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        log "ElizaOS process died. Restarting..."
        node direct-launch.js &
        SERVER_PID=$!
        log "ElizaOS restarted with PID $SERVER_PID"
    fi
    
    sleep 30
done 