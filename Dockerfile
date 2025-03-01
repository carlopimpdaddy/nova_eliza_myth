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
    echo '    echo "TWITTER_CLIENT=true" >> .env' >> start.sh && \
    echo '    echo "TWITTER_CLIENT_ENABLED=true" >> .env' >> start.sh && \
    echo '    echo "ENABLE_TWITTER=true" >> .env' >> start.sh && \
    echo '    echo "CLIENT_TYPES=twitter" >> .env' >> start.sh && \
    echo '    echo "AGENT_CLIENTS=twitter" >> .env' >> start.sh && \
    echo '    echo "AUTOPOST=true" >> .env' >> start.sh && \
    echo '    echo "AUTOPOST_INTERVAL=60" >> .env' >> start.sh && \
    echo '    echo "DEBUG=twitter*" >> .env' >> start.sh && \
    echo '    echo "Created .env file in $(pwd)"' >> start.sh && \
    echo '' >> start.sh && \
    echo '    # Also create .env file in the agent directory with all variable variations' >> start.sh && \
    echo '    if [ -d "agent" ]; then' >> start.sh && \
    echo '      echo "Creating .env file in agent directory..."' >> start.sh && \
    echo '      echo "TWITTER_API_KEY=$TWITTER_API_KEY" > agent/.env' >> start.sh && \
    echo '      echo "TWITTER_API_SECRET=$TWITTER_API_SECRET" >> agent/.env' >> start.sh && \
    echo '      echo "TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN" >> agent/.env' >> start.sh && \
    echo '      echo "TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET" >> agent/.env' >> start.sh && \
    echo '      echo "TWITTER_CLIENT=true" >> agent/.env' >> start.sh && \
    echo '      echo "TWITTER_CLIENT_ENABLED=true" >> agent/.env' >> start.sh && \
    echo '      echo "ENABLE_TWITTER=true" >> agent/.env' >> start.sh && \
    echo '      echo "CLIENT_TYPES=twitter" >> agent/.env' >> start.sh && \
    echo '      echo "AGENT_CLIENTS=twitter" >> agent/.env' >> start.sh && \
    echo '      echo "AUTOPOST=true" >> agent/.env' >> start.sh && \
    echo '      echo "AUTOPOST_INTERVAL=60" >> agent/.env' >> start.sh && \
    echo '      echo "DEBUG=twitter*" >> agent/.env' >> start.sh && \
    echo '      echo "Created .env file in $(pwd)/agent"' >> start.sh && \
    echo '    fi' >> start.sh && \
    echo '' >> start.sh && \
    echo '    # Run the agent with Twitter client enabled' >> start.sh && \
    echo '    echo "Starting ElizaOS with Twitter client..."' >> start.sh && \
    echo '    cd agent' >> start.sh && \
    echo '    export TWITTER_CLIENT=true' >> start.sh && \
    echo '    export TWITTER_CLIENT_ENABLED=true' >> start.sh && \
    echo '    export ENABLE_TWITTER=true' >> start.sh && \
    echo '    export CLIENT_TYPES=twitter' >> start.sh && \
    echo '    export AGENT_CLIENTS=twitter' >> start.sh && \
    echo '    export AUTOPOST=true' >> start.sh && \
    echo '    export AUTOPOST_INTERVAL=60' >> start.sh && \
    echo '    export DISPLAY_NAME="Nova 11 Wing"' >> start.sh && \
    echo '    export DEBUG=twitter*' >> start.sh && \
    echo '    NODE_OPTIONS="--no-warnings" pnpm start --isRoot --client twitter --autopost --interval=60 &' >> start.sh && \
    echo '    AGENT_PID=$!' >> start.sh && \
    echo '    echo "ElizaOS started with PID $AGENT_PID"' >> start.sh && \
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
RUN mkdir -p /app/agent/dist

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

# Build the ElizaOS application with Twitter client support
WORKDIR /app/eliza
RUN if [ -f "package.json" ]; then \
    pnpm install && \
    NODE_OPTIONS="--no-warnings" pnpm run build || echo "Build failed, but continuing"; \
    fi

# Create directory structure for Twitter client
RUN mkdir -p /app/eliza/agent/src/clients/twitter

# Create Twitter client module
RUN echo '// ElizaOS Twitter Client Module' > /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'import { TwitterApi } from "twitter-api-v2";' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'import type { Character } from "../../types";' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'import * as fs from "fs";' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'import * as path from "path";' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'const MINUTE_MS = 60 * 1000;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'const DEFAULT_INTERVAL = 60; // minutes' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'let twitterClient: TwitterApi | null = null;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'let postInterval: NodeJS.Timeout | null = null;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'let characterData: Character | null = null;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'let generateTweet: (() => Promise<string>) | null = null;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '// Function to check for missing Twitter credentials and log them' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'function checkCredentials() {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  const apiKey = process.env.TWITTER_API_KEY;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  const apiSecret = process.env.TWITTER_API_SECRET;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  const accessToken = process.env.TWITTER_ACCESS_TOKEN;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  const accessSecret = process.env.TWITTER_ACCESS_SECRET;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  console.log("Twitter credentials: {", ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    "apiKey:", apiKey ? "SET" : "MISSING", ', ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    "apiSecret:", apiSecret ? "SET" : "MISSING", ', ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    "accessToken:", accessToken ? "SET" : "MISSING", ', ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    "accessSecret:", accessSecret ? "SET" : "MISSING", ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  "}");' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (!apiKey || !apiSecret || !accessToken || !accessSecret) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return false;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  return true;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '}' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '// Initialize the Twitter client with credentials' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'function initializeTwitterClient(): TwitterApi | null {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  try {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    if (!checkCredentials()) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '      console.error("Missing Twitter credentials, cannot initialize Twitter client");' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '      return null;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    const client = new TwitterApi({' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '      appKey: process.env.TWITTER_API_KEY!,' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '      appSecret: process.env.TWITTER_API_SECRET!,' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '      accessToken: process.env.TWITTER_ACCESS_TOKEN!,' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '      accessSecret: process.env.TWITTER_ACCESS_SECRET!,' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    });' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return client;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  } catch (error) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.error("Error initializing Twitter client:", error);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return null;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '}' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '// Set up auto-posting at the specified interval' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'function setupAutopost(interval = DEFAULT_INTERVAL) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (!twitterClient || !generateTweet) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.error("Cannot set up autoposting without Twitter client and tweet generator");' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  console.log(`Setting up Twitter autopost every ${interval} minutes`);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  // Clear any existing interval' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (postInterval) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    clearInterval(postInterval);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  // Set up the interval for posting' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  postInterval = setInterval(async () => {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    try {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '      await postTweet();' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    } catch (error) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '      console.error("Error in autopost:", error);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }, interval * MINUTE_MS);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '}' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '// Generate a tweet based on the character data' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'async function generateTweetContent(): Promise<string> {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (!characterData) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return "Just another day in the life of an AI.";' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  // Use the character\'s post examples if available' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (characterData.postExamples && characterData.postExamples.length > 0) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    const randomIndex = Math.floor(Math.random() * characterData.postExamples.length);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return characterData.postExamples[randomIndex];' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  // If we have a custom generator function, use it' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (generateTweet) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return generateTweet();' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  // Fallback to a generic tweet' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  const defaultTweets = [' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    "Just pondering the vastness of space today. The universe is an endless frontier of possibility.",', ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    "Some days I wonder what lies beyond the stars we can see. What mysteries await us?",', ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    "Looking at the night sky and feeling both small and connected to something greater.",', ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    "The cosmos is within us. We\'re made of star stuff.",', ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    "Exploring new ideas today. What are you curious about?",', ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  ];' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  const randomIndex = Math.floor(Math.random() * defaultTweets.length);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  return defaultTweets[randomIndex];' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '}' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '// Post a tweet using the Twitter client' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'async function postTweet() {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (!twitterClient) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.error("Twitter client not initialized, cannot post tweet");' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  try {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    const tweetText = await generateTweetContent();' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.log("=================================================");' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.log("ELIZAOS TWITTER CLIENT - POSTING TWEET:");' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.log(tweetText);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.log("=================================================");' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    const response = await twitterClient.v2.tweet(tweetText);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.log("Tweet posted successfully:", response.data.id);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return response.data.id;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  } catch (error) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.error("Error posting tweet:", error);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return null;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '}' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '// Initialize the client module with a character' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'export function initialize(character: Character, options: any = {}) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  console.log(`ElizaOS Twitter client initializing for character: ${character.name}`);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  characterData = character;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  // Initialize Twitter client' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  twitterClient = initializeTwitterClient();' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (!twitterClient) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    console.error("Failed to initialize Twitter client");' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    return { initialized: false };' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  // Check for a custom tweet generator function' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (options.generateTweet) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    generateTweet = options.generateTweet;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  // Set up autoposting if requested' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  const autopost = options.autopost || process.env.AUTOPOST === "true";' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  let interval = DEFAULT_INTERVAL;' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  ' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  // Set interval from options or environment variable' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (options.interval) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    interval = parseInt(options.interval, 10);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  } else if (process.env.AUTOPOST_INTERVAL) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    interval = parseInt(process.env.AUTOPOST_INTERVAL, 10);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  if (autopost) {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '    setupAutopost(interval);' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  }' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  console.log("ElizaOS Twitter client initialized and ready");' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  return { initialized: true };' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '}' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '// Module exports' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo 'export default {' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  initialize,' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '  postTweet,' >> /app/eliza/agent/src/clients/twitter/index.ts && \
    echo '};' >> /app/eliza/agent/src/clients/twitter/index.ts

# Add Twitter API dependency to package.json
RUN cd /app/eliza/agent && \
    if [ -f "package.json" ]; then \
    sed -i 's/"dependencies": {/"dependencies": {\n    "twitter-api-v2": "^1.15.0",/g' package.json && \
    pnpm install; \
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

# Set the command to run the start script
CMD ["/app/start.sh"]