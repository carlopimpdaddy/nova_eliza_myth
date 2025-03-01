# Use a specific Node.js version for better reproducibility
FROM node:18-slim AS builder

# Install pnpm globally and necessary build tools
RUN npm install -g pnpm@9.15.4 && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    git \
    python3 \
    python3-pip \
    curl \
    node-gyp \
    ffmpeg \
    make \
    g++ \
    build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Python 3 as the default python
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Create health check app as a module that can be required by the agent
WORKDIR /app
RUN npm init -y && \
    npm install express && \
    echo 'const express = require("express");' > health-server.js && \
    echo 'const app = express();' >> health-server.js && \
    echo 'const port = process.env.PORT || 3000;' >> health-server.js && \
    echo 'function startServer() {' >> health-server.js && \
    echo '  console.log("Starting health check server on port:", port);' >> health-server.js && \
    echo '  app.get("/health", (req, res) => {' >> health-server.js && \
    echo '    console.log("Health check request received");' >> health-server.js && \
    echo '    res.status(200).json({ status: "ok" });' >> health-server.js && \
    echo '  });' >> health-server.js && \
    echo '  app.get("*", (req, res) => {' >> health-server.js && \
    echo '    console.log("Request received:", req.url);' >> health-server.js && \
    echo '    res.status(200).send("Service is running");' >> health-server.js && \
    echo '  });' >> health-server.js && \
    echo '  return app.listen(port, "0.0.0.0", () => {' >> health-server.js && \
    echo '    console.log(`Health check server running on port ${port}`);' >> health-server.js && \
    echo '  });' >> health-server.js && \
    echo '}' >> health-server.js && \
    echo 'module.exports = { startServer };' >> health-server.js && \
    echo 'if (require.main === module) {' >> health-server.js && \
    echo '  startServer();' >> health-server.js && \
    echo '}' >> health-server.js && \
    mkdir -p agent/dist

# Create a launcher script that starts health check server and ElizaOS app
RUN echo '#!/bin/sh' > start.sh && \
    echo 'echo "Starting ElizaOS with health check server..."' >> start.sh && \
    echo 'node health-server.js &' >> start.sh && \
    echo 'HEALTH_PID=$!' >> start.sh && \
    echo 'echo "Health check server started with PID $HEALTH_PID"' >> start.sh && \
    echo 'echo "Starting main ElizaOS application..."' >> start.sh && \
    echo 'cd /app/eliza && npm start' >> start.sh && \
    echo 'ELIZA_EXIT=$?' >> start.sh && \
    echo 'kill $HEALTH_PID' >> start.sh && \
    echo 'exit $ELIZA_EXIT' >> start.sh && \
    chmod +x start.sh

# Create package.json with proper configuration
RUN node -e "const pkg = require('./package.json'); \
    pkg.scripts = pkg.scripts || {}; \
    pkg.scripts.start = './start.sh'; \
    pkg.main = 'health-server.js'; \
    require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2));"

# Final image
FROM node:18-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y curl git python3 python3-pip make g++ build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy the health check server from builder
COPY --from=builder /app /app

# Clone and build the ElizaOS application
RUN mkdir -p /app/eliza
WORKDIR /app/eliza

# Copy the application code (assuming it's in the build context)
# Note: This will only work if you're building from a directory containing your ElizaOS code
COPY . /app/eliza

# Install dependencies and build the application
RUN npm install -g pnpm@9.15.4 && \
    pnpm install && \
    pnpm run build

# Set up types.ts if it's missing
RUN if [ ! -f "agent/src/types.ts" ]; then \
    echo 'export type ModelProviderName = "grok" | "openai" | "anthropic" | "perplexity" | "gemini";' > agent/src/types.ts && \
    echo 'export interface Character {' >> agent/src/types.ts && \
    echo '  name: string;' >> agent/src/types.ts && \
    echo '  database: any;' >> agent/src/types.ts && \
    echo '  username: string;' >> agent/src/types.ts && \
    echo '  screenName: string;' >> agent/src/types.ts && \
    echo '  plugins: any[];' >> agent/src/types.ts && \
    echo '  clients: string[];' >> agent/src/types.ts && \
    echo '  modelProvider: ModelProviderName;' >> agent/src/types.ts && \
    echo '  settings: any;' >> agent/src/types.ts && \
    echo '  system: string;' >> agent/src/types.ts && \
    echo '  bio: string[];' >> agent/src/types.ts && \
    echo '  lore: string[];' >> agent/src/types.ts && \
    echo '  messageExamples: any[][];' >> agent/src/types.ts && \
    echo '  postExamples: string[];' >> agent/src/types.ts && \
    echo '  topics: string[];' >> agent/src/types.ts && \
    echo '  style: {' >> agent/src/types.ts && \
    echo '    all: string[];' >> agent/src/types.ts && \
    echo '    chat: string[];' >> agent/src/types.ts && \
    echo '    post: string[];' >> agent/src/types.ts && \
    echo '  };' >> agent/src/types.ts && \
    echo '  adjectives: string[];' >> agent/src/types.ts && \
    echo '  extends: any[];' >> agent/src/types.ts && \
    echo '}' >> agent/src/types.ts; \
    fi

# Rebuild if we added types
RUN pnpm run build

WORKDIR /app
# Expose port for health check
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Start the application with our launcher script
CMD ["./start.sh"]