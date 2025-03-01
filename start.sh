#!/bin/sh
set -e

# Print diagnostic information
echo "Start script running in $(pwd) at $(date)"
echo "Directory contents: $(ls -la)"

# Start ElizaOS application if it exists
if [ -d "/app/eliza" ]; then
  echo "Starting main ElizaOS application with Twitter plugin..."
  cd /app/eliza
  echo "ElizaOS directory: $(pwd)"
  echo "Directory contents: $(ls -la)"

  # Only proceed if we have a package.json
  if [ -f "package.json" ]; then
    # Export NODE_OPTIONS to suppress version warnings
    export NODE_OPTIONS="--no-warnings"

    # Set up Twitter variables
    echo "Setting up Twitter variables..."
    # Map variables from actual environment names to what ElizaOS expects
    if [ -n "$TWITTER_API_SECRET_KEY" ]; then
      export TWITTER_API_SECRET="$TWITTER_API_SECRET_KEY"
      echo "Set TWITTER_API_SECRET from TWITTER_API_SECRET_KEY"
    fi
    if [ -n "$TWITTER_ACCESS_TOKEN_SECRET" ]; then
      export TWITTER_ACCESS_SECRET="$TWITTER_ACCESS_TOKEN_SECRET"
      echo "Set TWITTER_ACCESS_SECRET from TWITTER_ACCESS_TOKEN_SECRET"
    fi

    # Debug all environment variables
    echo "TWITTER ENVIRONMENT VARIABLES (after mapping):"
    echo "TWITTER_API_KEY=$TWITTER_API_KEY"
    echo "TWITTER_API_SECRET=$TWITTER_API_SECRET"
    echo "TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN"
    echo "TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET"

    # Only proceed with Twitter setup if all credentials are present
    if [ -z "$TWITTER_API_KEY" ] || [ -z "$TWITTER_API_SECRET" ] || [ -z "$TWITTER_ACCESS_TOKEN" ] || [ -z "$TWITTER_ACCESS_SECRET" ]; then
      echo "WARNING: Missing Twitter credentials. Twitter integration will not work."
    else
      echo "All Twitter credentials present, setting up Twitter integration"

      # Check if the plugin package is installed
      if [ -d "node_modules/@elizaos/plugin-twitter" ]; then
        echo "Found @elizaos/plugin-twitter package. Using built-in Twitter plugin."
      else
        echo "Twitter plugin package not found. Installing dependencies..."
        pnpm install || echo "Warning: pnpm install failed but continuing"
      fi

      # Create full .env file with all possible Twitter config variables
      echo "Creating .env files with Twitter configuration..."
      cat > .env << EOF
# Twitter API Credentials
TWITTER_API_KEY=$TWITTER_API_KEY
TWITTER_API_SECRET=$TWITTER_API_SECRET
TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN
TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET
TWITTER_BEARER_TOKEN=$TWITTER_ACCESS_TOKEN

# Twitter Plugin Configuration
ENABLE_PLUGINS=twitter
PLUGINS=twitter
ENABLE_TWITTER=true
TWITTER_ENABLED=true
TWITTER_AUTOPOST=true
TWITTER_AUTOPOST_INTERVAL=60
DISPLAY_NAME=Nova 11 Wing
DEBUG=twitter*,@elizaos/plugin-twitter*,@elizaos:*
LOG_LEVEL=debug
EOF

      # Copy .env to agent directory for direct access
      if [ -d "agent" ]; then
        cp .env agent/.env
        echo "Copied .env to agent directory"
      fi

      # Check and fix package.json to include the Twitter plugin
      if [ -f "package.json" ]; then
        echo "Checking package.json for Twitter plugin..."
        if ! grep -q "@elizaos/plugin-twitter" "package.json"; then
          echo "Twitter plugin not found in package.json, installing..."
          pnpm add @elizaos/plugin-twitter || echo "Warning: Failed to install Twitter plugin package"
        else
          echo "Twitter plugin already in package.json"
        fi
      fi

      # Set Twitter environment variables directly for the process
      export ENABLE_PLUGINS=twitter
      export PLUGINS=twitter
      export ENABLE_TWITTER=true
      export TWITTER_ENABLED=true
      export TWITTER_AUTOPOST=true
      export TWITTER_AUTOPOST_INTERVAL=60
      export DEBUG=twitter*,@elizaos/plugin-twitter*,@elizaos:*
      export LOG_LEVEL=debug
      export DISPLAY_NAME="Nova 11 Wing"

      # Start the agent with Twitter plugin activated with extra debug flags
      echo "Starting ElizaOS with Twitter plugin..."
      NODE_OPTIONS="--no-warnings" pnpm start --isRoot --plugin twitter --autopost --debug &
      AGENT_PID=$!
      echo "ElizaOS started with PID $AGENT_PID"
    fi
  else
    echo "No package.json found in ElizaOS directory"
  fi
else
  echo "ElizaOS directory not found"
fi

# Keep the container running
echo "ElizaOS services running. Container will stay alive."
while true; do
  sleep 30
  # Check health check server is still running
  if ! curl -s http://localhost:${PORT:-8080}/health > /dev/null; then
    echo "WARNING: Health check server not responding. Restarting..."
    node /app/health-server.js &
  fi
done 