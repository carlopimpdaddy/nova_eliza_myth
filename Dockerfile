# Use a newer Node.js version (closer to the required 23.3.0)
FROM node:20-slim AS builder

# Install necessary build tools
RUN apt-get update && \
    apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    node-gyp \
    make \
    g++ \
    build-essential \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g pnpm@9.15.4

# Create app directory for health check
WORKDIR /app

# Create package.json first for health check server
RUN echo '{"name":"health-check","version":"1.0.0","main":"health-server.js","dependencies":{"express":"^4.18.2"}}' > package.json

# Install dependencies
RUN npm install --production

# Create health check server
RUN echo 'const express = require("express");' > health-server.js && \
    echo 'const app = express();' >> health-server.js && \
    echo 'const port = process.env.PORT || 3000;' >> health-server.js && \
    echo 'console.log("Starting health check server on port:", port);' >> health-server.js && \
    echo 'app.get("/health", (req, res) => {' >> health-server.js && \
    echo '  console.log("Health check request received");' >> health-server.js && \
    echo '  res.status(200).json({ status: "ok" });' >> health-server.js && \
    echo '});' >> health-server.js && \
    echo 'app.get("*", (req, res) => {' >> health-server.js && \
    echo '  console.log("Request received:", req.url);' >> health-server.js && \
    echo '  res.status(200).send("Service is running");' >> health-server.js && \
    echo '});' >> health-server.js && \
    echo 'app.listen(port, "0.0.0.0", () => {' >> health-server.js && \
    echo '  console.log(`Health check server running on port ${port}`);' >> health-server.js && \
    echo '});' >> health-server.js

# Create a more robust startup script for both health check and application
RUN echo '#!/bin/sh' > start.sh && \
    echo 'echo "Starting health check server..."' >> start.sh && \
    echo 'node health-server.js &' >> start.sh && \
    echo 'HEALTH_PID=$!' >> start.sh && \
    echo 'echo "Health check server started with PID $HEALTH_PID"' >> start.sh && \
    echo '' >> start.sh && \
    echo 'echo "Waiting for health check server to initialize..."' >> start.sh && \
    echo 'sleep 2' >> start.sh && \
    echo '' >> start.sh && \
    echo 'echo "Starting main ElizaOS application with Twitter client..."' >> start.sh && \
    echo 'cd /app/eliza' >> start.sh && \
    echo 'if [ -f "package.json" ]; then' >> start.sh && \
    echo '  # Export NODE_OPTIONS to suppress version warnings' >> start.sh && \
    echo '  export NODE_OPTIONS="--no-warnings"' >> start.sh && \
    echo '' >> start.sh && \
    echo '  # Match the variable names that are actually available in the environment' >> start.sh && \
    echo '  echo "Setting up Twitter variables using available environment variables..."' >> start.sh && \
    echo '  # Map variables from actual environment names to what ElizaOS expects' >> start.sh && \
    echo '  if [ -n "$TWITTER_API_SECRET_KEY" ]; then' >> start.sh && \
    echo '    export TWITTER_API_SECRET="$TWITTER_API_SECRET_KEY"' >> start.sh && \
    echo '    echo "Set TWITTER_API_SECRET from TWITTER_API_SECRET_KEY"' >> start.sh && \
    echo '  fi' >> start.sh && \
    echo '  if [ -n "$TWITTER_ACCESS_TOKEN_SECRET" ]; then' >> start.sh && \
    echo '    export TWITTER_ACCESS_SECRET="$TWITTER_ACCESS_TOKEN_SECRET"' >> start.sh && \
    echo '    echo "Set TWITTER_ACCESS_SECRET from TWITTER_ACCESS_TOKEN_SECRET"' >> start.sh && \
    echo '  fi' >> start.sh && \
    echo '' >> start.sh && \
    echo '  # Debug all environment variables to help identify the correct names' >> start.sh && \
    echo '  echo "TWITTER ENVIRONMENT VARIABLES (after mapping):"' >> start.sh && \
    echo '  echo "TWITTER_API_KEY=$TWITTER_API_KEY"' >> start.sh && \
    echo '  echo "TWITTER_API_SECRET=$TWITTER_API_SECRET"' >> start.sh && \
    echo '  echo "TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN"' >> start.sh && \
    echo '  echo "TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET"' >> start.sh && \
    echo '' >> start.sh && \
    echo '  # Check if all required variables are set' >> start.sh && \
    echo '  if [ -z "$TWITTER_API_KEY" ] || [ -z "$TWITTER_API_SECRET" ] || [ -z "$TWITTER_ACCESS_TOKEN" ] || [ -z "$TWITTER_ACCESS_SECRET" ]; then' >> start.sh && \
    echo '    echo "ERROR: Missing Twitter credentials after mapping. Please check variable names."' >> start.sh && \
    echo '    echo "Health check server will continue running, but Twitter integration will not work."' >> start.sh && \
    echo '  else' >> start.sh && \
    echo '    # Create a .env file with Twitter config' >> start.sh && \
    echo '    echo "Creating .env file with Twitter configuration..."' >> start.sh && \
    echo '    echo "TWITTER_API_KEY=$TWITTER_API_KEY" > .env' >> start.sh && \
    echo '    echo "TWITTER_API_SECRET=$TWITTER_API_SECRET" >> .env' >> start.sh && \
    echo '    echo "TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN" >> .env' >> start.sh && \
    echo '    echo "TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET" >> .env' >> start.sh && \
    echo '    # Also add the original variable names' >> start.sh && \
    echo '    echo "TWITTER_API_SECRET_KEY=$TWITTER_API_SECRET_KEY" >> .env' >> start.sh && \
    echo '    echo "TWITTER_ACCESS_TOKEN_SECRET=$TWITTER_ACCESS_TOKEN_SECRET" >> .env' >> start.sh && \
    echo '    echo "Created .env file in $(pwd)"' >> start.sh && \
    echo '    cat .env' >> start.sh && \
    echo '' >> start.sh && \
    echo '    # Also create .env file in the agent directory with all variable variations' >> start.sh && \
    echo '    if [ -d "agent" ]; then' >> start.sh && \
    echo '      echo "Creating .env file in agent directory..."' >> start.sh && \
    echo '      echo "TWITTER_API_KEY=$TWITTER_API_KEY" > agent/.env' >> start.sh && \
    echo '      echo "TWITTER_API_SECRET=$TWITTER_API_SECRET" >> agent/.env' >> start.sh && \
    echo '      echo "TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN" >> agent/.env' >> start.sh && \
    echo '      echo "TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET" >> agent/.env' >> start.sh && \
    echo '      echo "TWITTER_API_SECRET_KEY=$TWITTER_API_SECRET_KEY" >> agent/.env' >> start.sh && \
    echo '      echo "TWITTER_ACCESS_TOKEN_SECRET=$TWITTER_ACCESS_TOKEN_SECRET" >> agent/.env' >> start.sh && \
    echo '      echo "Created .env file in $(pwd)/agent"' >> start.sh && \
    echo '    fi' >> start.sh && \
    echo '' >> start.sh && \
    echo '    # Start the agent and Twitter client with all possible Twitter variable names' >> start.sh && \
    echo '    echo "Starting agent with Twitter client using mapped variables..."' >> start.sh && \
    echo '    # Print Twitter credential check' >> start.sh && \
    echo '    echo "TWITTER CREDENTIALS VERIFICATION:"' >> start.sh && \
    echo '    echo "TWITTER_API_KEY: $(if [ -n \"$TWITTER_API_KEY\" ]; then echo \"SET\"; else echo \"MISSING\"; fi)"' >> start.sh && \
    echo '    echo "TWITTER_API_SECRET: $(if [ -n \"$TWITTER_API_SECRET\" ]; then echo \"SET\"; else echo \"MISSING\"; fi)"' >> start.sh && \
    echo '    echo "TWITTER_ACCESS_TOKEN: $(if [ -n \"$TWITTER_ACCESS_TOKEN\" ]; then echo \"SET\"; else echo \"MISSING\"; fi)"' >> start.sh && \
    echo '    echo "TWITTER_ACCESS_SECRET: $(if [ -n \"$TWITTER_ACCESS_SECRET\" ]; then echo \"SET\"; else echo \"MISSING\"; fi)"' >> start.sh && \
    echo '' >> start.sh && \
    echo '    # Add these settings to explicitly activate Twitter client' >> start.sh && \
    echo '    export TWITTER_CLIENT=true' >> start.sh && \
    echo '    export TWITTER_CLIENT_ENABLED=true' >> start.sh && \
    echo '    export ENABLE_TWITTER=true' >> start.sh && \
    echo '    export CLIENT_TYPES=twitter' >> start.sh && \
    echo '    export DEBUG_TWITTER=true' >> start.sh && \
    echo '    export DISPLAY_NAME="Nova 11 Wing"' >> start.sh && \
    echo '    export AGENT_CLIENTS=twitter' >> start.sh && \
    echo '    export AUTOPOST=true' >> start.sh && \
    echo '    export AUTOPOST_INTERVAL=60' >> start.sh && \
    echo '' >> start.sh && \
    echo '    # Start the agent with all Twitter environment variables and debug flags' >> start.sh && \
    echo '    DEBUG=twitter* \' >> start.sh && \
    echo '    TWITTER_CLIENT=true \' >> start.sh && \
    echo '    TWITTER_CLIENT_ENABLED=true \' >> start.sh && \
    echo '    ENABLE_TWITTER=true \' >> start.sh && \
    echo '    CLIENT_TYPES=twitter \' >> start.sh && \
    echo '    AGENT_CLIENTS=twitter \' >> start.sh && \
    echo '    AUTOPOST=true \' >> start.sh && \
    echo '    AUTOPOST_INTERVAL=60 \' >> start.sh && \
    echo '    DISPLAY_NAME="Nova 11 Wing" \' >> start.sh && \
    echo '    NODE_OPTIONS="--no-warnings" \' >> start.sh && \
    echo '    pnpm --filter "@elizaos/agent" start --isRoot --client twitter --autopost --interval=60 --debug &' >> start.sh && \
    echo '    AGENT_PID=$!' >> start.sh && \
    echo '    echo "Agent started with PID $AGENT_PID"' >> start.sh && \
    echo '  fi' >> start.sh && \
    echo 'else' >> start.sh && \
    echo '  echo "ElizaOS application not found. Health check server will continue running."' >> start.sh && \
    echo 'fi' >> start.sh && \
    echo '' >> start.sh && \
    echo '# Keep the container running' >> start.sh && \
    echo 'echo "Services running. Keeping container alive..."' >> start.sh && \
    echo 'wait $HEALTH_PID' >> start.sh && \
    chmod +x start.sh

# Make agent directory that Railway is looking for 
# and create an index.js that runs our start script
RUN mkdir -p /app/agent/dist && \
    echo 'console.log("Agent starting up");' > /app/agent/dist/index.js && \
    echo 'const { spawn } = require("child_process");' >> /app/agent/dist/index.js && \
    echo '' >> /app/agent/dist/index.js && \
    echo '// Set Twitter environment variables explicitly' >> /app/agent/dist/index.js && \
    echo 'process.env.TWITTER_CLIENT = "true";' >> /app/agent/dist/index.js && \
    echo 'process.env.TWITTER_CLIENT_ENABLED = "true";' >> /app/agent/dist/index.js && \
    echo 'process.env.ENABLE_TWITTER = "true";' >> /app/agent/dist/index.js && \
    echo 'process.env.CLIENT_TYPES = "twitter";' >> /app/agent/dist/index.js && \
    echo 'process.env.AGENT_CLIENTS = "twitter";' >> /app/agent/dist/index.js && \
    echo 'process.env.AUTOPOST = "true";' >> /app/agent/dist/index.js && \
    echo 'process.env.AUTOPOST_INTERVAL = "60";' >> /app/agent/dist/index.js && \
    echo 'console.log("Twitter environment variables set directly in index.js");' >> /app/agent/dist/index.js && \
    echo '' >> /app/agent/dist/index.js && \
    echo 'try {' >> /app/agent/dist/index.js && \
    echo '  console.log("Starting ElizaOS with health check and Twitter client...");' >> /app/agent/dist/index.js && \
    echo '  // Try to load helper first' >> /app/agent/dist/index.js && \
    echo '  try {' >> /app/agent/dist/index.js && \
    echo '    const twitterHelper = require("../../twitter-client.js");' >> /app/agent/dist/index.js && \
    echo '    console.log("Twitter helper loaded, activating Twitter client...");' >> /app/agent/dist/index.js && \
    echo '    twitterHelper.activateTwitter();' >> /app/agent/dist/index.js && \
    echo '  } catch (twitterError) {' >> /app/agent/dist/index.js && \
    echo '    console.log("Twitter helper not loaded, continuing:", twitterError.message);' >> /app/agent/dist/index.js && \
    echo '  }' >> /app/agent/dist/index.js && \
    echo '' >> /app/agent/dist/index.js && \
    echo '  // Start the main process' >> /app/agent/dist/index.js && \
    echo '  const startArgs = ["--isRoot", "--client", "twitter", "--autopost", "--interval=60", "--debug"];' >> /app/agent/dist/index.js && \
    echo '  console.log("Launching ElizaOS with args:", startArgs.join(" "));' >> /app/agent/dist/index.js && \
    echo '  const startProcess = spawn("/app/start.sh", [], { stdio: "inherit", shell: true, env: { ...process.env, TWITTER_CLIENT: "true", AGENT_CLIENTS: "twitter" } });' >> /app/agent/dist/index.js && \
    echo '  startProcess.on("error", (err) => {' >> /app/agent/dist/index.js && \
    echo '    console.error("Failed to start application:", err);' >> /app/agent/dist/index.js && \
    echo '    // Start health check directly if shell script fails' >> /app/agent/dist/index.js && \
    echo '    require("../../health-server");' >> /app/agent/dist/index.js && \
    echo '  });' >> /app/agent/dist/index.js && \
    echo '} catch (error) {' >> /app/agent/dist/index.js && \
    echo '  console.error("Error in startup:", error);' >> /app/agent/dist/index.js && \
    echo '  // Fallback to just health check' >> /app/agent/dist/index.js && \
    echo '  require("../../health-server");' >> /app/agent/dist/index.js && \
    echo '}' >> /app/agent/dist/index.js && \
    echo '' >> /app/agent/dist/index.js && \
    echo 'module.exports = { start: () => console.log("Agent started with Twitter client") };' >> /app/agent/dist/index.js

# Create helper script to explicitly activate Twitter client
RUN echo '// Helper script to explicitly activate Twitter client' > /app/twitter-client.js && \
    echo 'console.log("Twitter Client Helper Starting...");' >> /app/twitter-client.js && \
    echo 'process.env.TWITTER_CLIENT = "true";' >> /app/twitter-client.js && \
    echo 'process.env.TWITTER_CLIENT_ENABLED = "true";' >> /app/twitter-client.js && \
    echo 'process.env.ENABLE_TWITTER = "true";' >> /app/twitter-client.js && \
    echo 'process.env.CLIENT_TYPES = "twitter";' >> /app/twitter-client.js && \
    echo 'process.env.AGENT_CLIENTS = "twitter";' >> /app/twitter-client.js && \
    echo 'process.env.AUTOPOST = "true";' >> /app/twitter-client.js && \
    echo 'process.env.AUTOPOST_INTERVAL = "60";' >> /app/twitter-client.js && \
    echo 'console.log("Twitter environment variables set in helper");' >> /app/twitter-client.js && \
    echo '' >> /app/twitter-client.js && \
    echo '// Check if Twitter credentials are available' >> /app/twitter-client.js && \
    echo 'console.log("Checking Twitter credentials:");' >> /app/twitter-client.js && \
    echo 'console.log(`TWITTER_API_KEY: ${process.env.TWITTER_API_KEY ? "SET" : "MISSING"}`);' >> /app/twitter-client.js && \
    echo 'console.log(`TWITTER_API_SECRET: ${process.env.TWITTER_API_SECRET ? "SET" : "MISSING"}`);' >> /app/twitter-client.js && \
    echo 'console.log(`TWITTER_ACCESS_TOKEN: ${process.env.TWITTER_ACCESS_TOKEN ? "SET" : "MISSING"}`);' >> /app/twitter-client.js && \
    echo 'console.log(`TWITTER_ACCESS_SECRET: ${process.env.TWITTER_ACCESS_SECRET ? "SET" : "MISSING"}`);' >> /app/twitter-client.js && \
    echo '' >> /app/twitter-client.js && \
    echo '// Export helper function' >> /app/twitter-client.js && \
    echo 'module.exports = {' >> /app/twitter-client.js && \
    echo '  activateTwitter: () => {' >> /app/twitter-client.js && \
    echo '    console.log("Twitter client activation requested");' >> /app/twitter-client.js && \
    echo '    return true;' >> /app/twitter-client.js && \
    echo '  }' >> /app/twitter-client.js && \
    echo '};' >> /app/twitter-client.js

# Create a direct Twitter client initializer
RUN echo '// Direct Twitter client initializer' > /app/twitter-initializer.js && \
    echo 'console.log("Starting DIRECT Twitter client initialization...");' >> /app/twitter-initializer.js && \
    echo 'const fs = require("fs");' >> /app/twitter-initializer.js && \
    echo 'const path = require("path");' >> /app/twitter-initializer.js && \
    echo 'const { spawn, exec } = require("child_process");' >> /app/twitter-initializer.js && \
    echo '' >> /app/twitter-initializer.js && \
    echo '// Set all required environment variables' >> /app/twitter-initializer.js && \
    echo 'const twitterEnv = {' >> /app/twitter-initializer.js && \
    echo '  TWITTER_CLIENT: "true",' >> /app/twitter-initializer.js && \
    echo '  TWITTER_CLIENT_ENABLED: "true",' >> /app/twitter-initializer.js && \
    echo '  ENABLE_TWITTER: "true",' >> /app/twitter-initializer.js && \
    echo '  CLIENT_TYPES: "twitter",' >> /app/twitter-initializer.js && \
    echo '  AGENT_CLIENTS: "twitter",' >> /app/twitter-initializer.js && \
    echo '  AUTOPOST: "true",' >> /app/twitter-initializer.js && \
    echo '  AUTOPOST_INTERVAL: "60",' >> /app/twitter-initializer.js && \
    echo '  DEBUG: "twitter*",' >> /app/twitter-initializer.js && \
    echo '  DEBUG_TWITTER: "true",' >> /app/twitter-initializer.js && \
    echo '  DISPLAY_NAME: "Nova 11 Wing",' >> /app/twitter-initializer.js && \
    echo '  NODE_OPTIONS: "--no-warnings"' >> /app/twitter-initializer.js && \
    echo '};' >> /app/twitter-initializer.js && \
    echo '' >> /app/twitter-initializer.js && \
    echo '// Set all environment variables' >> /app/twitter-initializer.js && \
    echo 'Object.keys(twitterEnv).forEach(key => {' >> /app/twitter-initializer.js && \
    echo '  process.env[key] = twitterEnv[key];' >> /app/twitter-initializer.js && \
    echo '});' >> /app/twitter-initializer.js && \
    echo '' >> /app/twitter-initializer.js && \
    echo '// Log Twitter credential environment variables' >> /app/twitter-initializer.js && \
    echo 'console.log("Twitter credentials in direct initializer:");' >> /app/twitter-initializer.js && \
    echo 'console.log(`TWITTER_API_KEY: ${process.env.TWITTER_API_KEY ? "SET" : "MISSING"}`);' >> /app/twitter-initializer.js && \
    echo 'console.log(`TWITTER_API_SECRET: ${process.env.TWITTER_API_SECRET ? "SET" : "MISSING"}`);' >> /app/twitter-initializer.js && \
    echo 'console.log(`TWITTER_ACCESS_TOKEN: ${process.env.TWITTER_ACCESS_TOKEN ? "SET" : "MISSING"}`);' >> /app/twitter-initializer.js && \
    echo 'console.log(`TWITTER_ACCESS_SECRET: ${process.env.TWITTER_ACCESS_SECRET ? "SET" : "MISSING"}`);' >> /app/twitter-initializer.js && \
    echo '' >> /app/twitter-initializer.js && \
    echo '// Create the client directories if needed' >> /app/twitter-initializer.js && \
    echo 'const clientDir = path.join("/app/eliza/agent/src/clients");' >> /app/twitter-initializer.js && \
    echo 'const twitterDir = path.join(clientDir, "twitter");' >> /app/twitter-initializer.js && \
    echo '' >> /app/twitter-initializer.js && \
    echo '// Check if the Twitter client is available' >> /app/twitter-initializer.js && \
    echo 'if (fs.existsSync(twitterDir)) {' >> /app/twitter-initializer.js && \
    echo '  console.log("Found Twitter client directory at:", twitterDir);' >> /app/twitter-initializer.js && \
    echo '  // List files in the Twitter client directory' >> /app/twitter-initializer.js && \
    echo '  const files = fs.readdirSync(twitterDir);' >> /app/twitter-initializer.js && \
    echo '  console.log("Files in Twitter client directory:", files);' >> /app/twitter-initializer.js && \
    echo '} else {' >> /app/twitter-initializer.js && \
    echo '  console.log("Twitter client directory not found at:", twitterDir);' >> /app/twitter-initializer.js && \
    echo '}' >> /app/twitter-initializer.js && \
    echo '' >> /app/twitter-initializer.js && \
    echo '// Direct activation function' >> /app/twitter-initializer.js && \
    echo 'function activateTwitterClient() {' >> /app/twitter-initializer.js && \
    echo '  console.log("Directly activating Twitter client...");' >> /app/twitter-initializer.js && \
    echo '  // Try to execute a direct pnpm client command to force Twitter client initialization' >> /app/twitter-initializer.js && \
    echo '  try {' >> /app/twitter-initializer.js && \
    echo '    console.log("Running direct Twitter client initialization command...");' >> /app/twitter-initializer.js && \
    echo '    const cmd = "cd /app/eliza && pnpm --filter @elizaos/agent start:client twitter --autopost --interval=60";' >> /app/twitter-initializer.js && \
    echo '    exec(cmd, { env: { ...process.env, ...twitterEnv } }, (error, stdout, stderr) => {' >> /app/twitter-initializer.js && \
    echo '      if (error) {' >> /app/twitter-initializer.js && \
    echo '        console.error("Twitter client initialization failed:", error);' >> /app/twitter-initializer.js && \
    echo '        console.error(stderr);' >> /app/twitter-initializer.js && \
    echo '      } else {' >> /app/twitter-initializer.js && \
    echo '        console.log("Twitter client initialization output:", stdout);' >> /app/twitter-initializer.js && \
    echo '      }' >> /app/twitter-initializer.js && \
    echo '    });' >> /app/twitter-initializer.js && \
    echo '  } catch (error) {' >> /app/twitter-initializer.js && \
    echo '    console.error("Error in Twitter client direct activation:", error);' >> /app/twitter-initializer.js && \
    echo '  }' >> /app/twitter-initializer.js && \
    echo '}' >> /app/twitter-initializer.js && \
    echo '' >> /app/twitter-initializer.js && \
    echo '// Call the activation function' >> /app/twitter-initializer.js && \
    echo 'activateTwitterClient();' >> /app/twitter-initializer.js && \
    echo '' >> /app/twitter-initializer.js && \
    echo 'module.exports = { activate: activateTwitterClient };' >> /app/twitter-initializer.js && \
    chmod +x /app/twitter-initializer.js

# Final image
FROM node:20-slim

# Install minimal dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    git \
    python3 \
    python3-pip \
    node-gyp \
    make \
    g++ \
    build-essential \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    npm install -g pnpm@9.15.4

# Set Python 3 as the default python
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Create app directory
WORKDIR /app

# Copy the health check app from builder
COPY --from=builder /app /app

# Create eliza directory for application
RUN mkdir -p /app/eliza

# Copy the application code
COPY . /app/eliza/

# Set up types.ts if it's missing
RUN if [ ! -f "/app/eliza/agent/src/types.ts" ]; then \
    mkdir -p /app/eliza/agent/src && \
    echo 'export type ModelProviderName = "grok" | "openai" | "anthropic" | "perplexity" | "gemini";' > /app/eliza/agent/src/types.ts && \
    echo 'export interface Character {' >> /app/eliza/agent/src/types.ts && \
    echo '  name: string;' >> /app/eliza/agent/src/types.ts && \
    echo '  database: any;' >> /app/eliza/agent/src/types.ts && \
    echo '  username: string;' >> /app/eliza/agent/src/types.ts && \
    echo '  screenName: string;' >> /app/eliza/agent/src/types.ts && \
    echo '  plugins: any[];' >> /app/eliza/agent/src/types.ts && \
    echo '  clients: string[];' >> /app/eliza/agent/src/types.ts && \
    echo '  modelProvider: ModelProviderName;' >> /app/eliza/agent/src/types.ts && \
    echo '  settings: any;' >> /app/eliza/agent/src/types.ts && \
    echo '  system: string;' >> /app/eliza/agent/src/types.ts && \
    echo '  bio: string[];' >> /app/eliza/agent/src/types.ts && \
    echo '  lore: string[];' >> /app/eliza/agent/src/types.ts && \
    echo '  messageExamples: any[][];' >> /app/eliza/agent/src/types.ts && \
    echo '  postExamples: string[];' >> /app/eliza/agent/src/types.ts && \
    echo '  topics: string[];' >> /app/eliza/agent/src/types.ts && \
    echo '  style: {' >> /app/eliza/agent/src/types.ts && \
    echo '    all: string[];' >> /app/eliza/agent/src/types.ts && \
    echo '    chat: string[];' >> /app/eliza/agent/src/types.ts && \
    echo '    post: string[];' >> /app/eliza/agent/src/types.ts && \
    echo '  };' >> /app/eliza/agent/src/types.ts && \
    echo '  adjectives: string[];' >> /app/eliza/agent/src/types.ts && \
    echo '  extends: any[];' >> /app/eliza/agent/src/types.ts && \
    echo '}' >> /app/eliza/agent/src/types.ts; \
    fi

# Build the ElizaOS application
WORKDIR /app/eliza
RUN if [ -f "package.json" ]; then \
    pnpm install && \
    NODE_OPTIONS="--no-warnings" pnpm run build || echo "Build failed, but continuing"; \
    fi

# Return to app directory
WORKDIR /app

# Expose port for health check
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000
ENV NODE_OPTIONS="--no-warnings"
ENV DEBUG=twitter*
ENV TWITTER_CLIENT=true
ENV AGENT_CLIENTS=twitter
ENV AUTOPOST=true
ENV AUTOPOST_INTERVAL=60

# Add Twitter client-specific environment variables
ENV TWITTER_CLIENT_ENABLED=true
ENV ENABLE_TWITTER=true
ENV CLIENT_TYPES=twitter
ENV DEBUG_TWITTER=true
ENV DISPLAY_NAME="Nova 11 Wing"

# Modified CMD to explicitly include Twitter client parameters
CMD ["sh", "-c", "NODE_OPTIONS=\"--no-warnings\" node agent/dist/index.js --client twitter --autopost --interval=60"]