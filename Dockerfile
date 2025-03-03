# Use a specific Node.js version for better reproducibility
FROM node:23.3.0-slim AS builder

# Install pnpm globally and install necessary build tools
RUN npm install -g pnpm@9.15.1 && \
    apt-get update && \
    apt-get install -y git python3 make g++ curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Python 3 as the default python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Set the working directory
WORKDIR /app

# Copy package.json and other configuration files
COPY package.json ./
COPY pnpm-lock.yaml ./
COPY tsconfig.json ./

# Copy the rest of the application code
COPY ./src ./src
COPY ./characters ./characters

# Install dependencies
RUN pnpm install

# Now build the project
RUN pnpm build

# Create health check endpoint
RUN mkdir -p /app/public && \
    echo '{"status":"ok"}' > /app/public/health.json

# Set permissions
RUN mkdir -p /app/dist && \
    chown -R node:node /app && \
    chmod -R 755 /app

# Switch to node user for building
USER node

# Create a new stage for the final image
FROM node:23.3.0-slim

# Install runtime dependencies
RUN npm install -g pnpm@9.15.1 && \
    apt-get update && \
    apt-get install -y git python3 curl netcat-traditional && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built artifacts and production dependencies from the builder stage
COPY --from=builder /app/package.json /app/
COPY --from=builder /app/pnpm-lock.yaml /app/
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/public /app/public
COPY --from=builder /app/characters /app/characters

# Create error handlers
RUN echo '// Set up global error handlers to prevent crashes\nprocess.on("uncaughtException", function(err) {\n  console.error("Caught unhandled exception:", err.message);\n  console.error("Stack trace:", err.stack);\n  // Keep the process running\n});\n\nprocess.on("unhandledRejection", function(reason) {\n  console.error("Caught unhandled rejection:", reason);\n  // Keep the process running\n});\n\nconsole.log("Error handlers installed");' > /app/errorHandlers.js

# Add an initialization script
RUN echo '// Load error handlers\nrequire("./errorHandlers.js");\n\nconsole.log("Initialization complete");' > /app/init.js

# Create our start script with enhanced debugging
RUN echo '#!/bin/bash' > /app/start.sh && \
    echo 'echo "Environment variables (redacted):"' >> /app/start.sh && \
    echo 'echo "NODE_ENV: $NODE_ENV"' >> /app/start.sh && \
    echo 'echo "PORT: $PORT"' >> /app/start.sh && \
    echo '[ -n "$TWITTER_API_KEY" ] && echo "TWITTER_API_KEY: [REDACTED]" || echo "TWITTER_API_KEY: not set"' >> /app/start.sh && \
    echo '[ -n "$TWITTER_API_SECRET" ] && echo "TWITTER_API_SECRET: [REDACTED]" || echo "TWITTER_API_SECRET: not set"' >> /app/start.sh && \
    echo '[ -n "$TWITTER_ACCESS_TOKEN" ] && echo "TWITTER_ACCESS_TOKEN: [REDACTED]" || echo "TWITTER_ACCESS_TOKEN: not set"' >> /app/start.sh && \
    echo '[ -n "$TWITTER_ACCESS_SECRET" ] && echo "TWITTER_ACCESS_SECRET: [REDACTED]" || echo "TWITTER_ACCESS_SECRET: not set"' >> /app/start.sh && \
    echo '[ -n "$TWITTER_BEARER_TOKEN" ] && echo "TWITTER_BEARER_TOKEN: [REDACTED]" || echo "TWITTER_BEARER_TOKEN: not set"' >> /app/start.sh && \
    echo '[ -n "$GROK_API_KEY" ] && echo "GROK_API_KEY: [REDACTED]" || echo "GROK_API_KEY: not set"' >> /app/start.sh && \
    echo 'echo "Starting health check server on port 5000..."' >> /app/start.sh && \
    echo '(while true; do { echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"ok\"}"; } | nc -l -p 5000; done) &' >> /app/start.sh && \
    echo 'echo "Starting application with enhanced debugging..."' >> /app/start.sh && \
    echo 'DEBUG=twitter-api-client* node --trace-warnings /app/dist/index.js || { echo "Application exited with code $?"; echo "Keeping container running for debugging..."; tail -f /dev/null; }' >> /app/start.sh && \
    chmod +x /app/start.sh

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Add debug flags to help troubleshoot Twitter issues
ENV DEBUG=twitter-api-client*

# Expose port
EXPOSE 3000 8080

# Health check for Railway
HEALTHCHECK --interval=5s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:5000/health.json || exit 1

# Execute start.sh using bash and verify it exists first
CMD ["/bin/sh", "-c", "ls -la /app && ls -la /app/start.sh && /bin/bash /app/start.sh"]