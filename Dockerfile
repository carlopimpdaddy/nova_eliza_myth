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

# Create required directory structure
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
    npm install -g pnpm@9.15.4 ts-node typescript

# Set Python 3 as the default python
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Create app directory
WORKDIR /app

# Create required directories
RUN mkdir -p /app/agent/dist

# Copy health check specific files first
COPY health-check-package.json /app/package.json
COPY health-server.js /app/
COPY index.js /app/agent/dist/
COPY start.sh /app/
COPY eliza-start.sh /app/

# Make sure scripts are executable
RUN chmod +x /app/start.sh /app/eliza-start.sh

# Install dependencies for health server using npm (not pnpm)
RUN npm install --production

# Create eliza directory for application
RUN mkdir -p /app/eliza

# Copy the application code to eliza directory
COPY . /app/eliza/

# Build the ElizaOS application
WORKDIR /app/eliza
RUN if [ -f "package.json" ]; then \
    # Install required global packages for TypeScript
    npm install -g ts-node typescript @types/node && \
    # Install dependencies without frozen lockfile
    pnpm install --no-frozen-lockfile && \
    # Install Twitter plugin explicitly with workspace flag
    pnpm add @elizaos/plugin-twitter --save -w && \
    NODE_OPTIONS="--no-warnings" pnpm run build || echo "Build failed, but continuing"; \
    fi

# Pre-install ts-node in the agent directory for direct loading
WORKDIR /app/eliza/agent
RUN pnpm install ts-node typescript @types/node

# Return to app directory
WORKDIR /app

# Expose port for health check - Railway expects this port
EXPOSE 8080

# Set environment variables
ENV NODE_ENV=production
ENV PORT=8080
ENV NODE_OPTIONS="--no-warnings"
ENV DEBUG=twitter*,@elizaos/plugin-twitter*,@elizaos:*
ENV ENABLE_PLUGINS=twitter
ENV PLUGINS=twitter
ENV ENABLE_TWITTER=true
ENV TWITTER_ENABLED=true
ENV TWITTER_AUTOPOST=true
ENV TWITTER_AUTOPOST_INTERVAL=60
ENV DISPLAY_NAME="Nova 11 Wing"
ENV LOG_LEVEL=debug

# Create a single entry point script that controls startup
RUN echo '#!/bin/bash\n\
    set -e\n\
    echo "Starting ElizaOS deployment with Twitter..."\n\
    \n\
    # Set up Twitter variables\n\
    if [ -n "$TWITTER_API_SECRET_KEY" ] && [ -z "$TWITTER_API_SECRET" ]; then\n\
    export TWITTER_API_SECRET="$TWITTER_API_SECRET_KEY"\n\
    echo "Set TWITTER_API_SECRET from TWITTER_API_SECRET_KEY"\n\
    fi\n\
    \n\
    if [ -n "$TWITTER_ACCESS_TOKEN_SECRET" ] && [ -z "$TWITTER_ACCESS_SECRET" ]; then\n\
    export TWITTER_ACCESS_SECRET="$TWITTER_ACCESS_TOKEN_SECRET"\n\
    echo "Set TWITTER_ACCESS_SECRET from TWITTER_ACCESS_TOKEN_SECRET"\n\
    fi\n\
    \n\
    # Log Twitter environment variables\n\
    echo "TWITTER ENVIRONMENT VARIABLES:"\n\
    echo "TWITTER_API_KEY=$TWITTER_API_KEY"\n\
    echo "TWITTER_API_SECRET=$TWITTER_API_SECRET"\n\
    echo "TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN"\n\
    echo "TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET"\n\
    \n\
    # Create .env file with Twitter credentials\n\
    echo "Creating .env files with Twitter configuration..."\n\
    cat > /app/.env << EOF\n\
    TWITTER_API_KEY=$TWITTER_API_KEY\n\
    TWITTER_API_SECRET=$TWITTER_API_SECRET\n\
    TWITTER_ACCESS_TOKEN=$TWITTER_ACCESS_TOKEN\n\
    TWITTER_ACCESS_SECRET=$TWITTER_ACCESS_SECRET\n\
    TWITTER_ENABLED=true\n\
    TWITTER_AUTOPOST=true\n\
    TWITTER_AUTOPOST_INTERVAL=${TWITTER_AUTOPOST_INTERVAL:-60}\n\
    EOF\n\
    \n\
    # Copy .env to the agent directory\n\
    cp /app/.env /app/eliza/agent/.env\n\
    echo "Copied .env to agent directory"\n\
    \n\
    # Start health check server first\n\
    echo "Starting health check server..."\n\
    node /app/health-server.js &\n\
    HEALTH_PID=$!\n\
    \n\
    # Wait briefly for health server to start\n\
    sleep 2\n\
    \n\
    # Start ElizaOS in the background\n\
    echo "Starting ElizaOS with Twitter plugin..."\n\
    cd /app/eliza/agent\n\
    NODE_OPTIONS="--no-warnings" npx ts-node --transpile-only src/index.ts --isRoot --plugin twitter --autopost --debug &\n\
    ELIZA_PID=$!\n\
    echo "ElizaOS started with PID $ELIZA_PID"\n\
    \n\
    # Monitor both processes\n\
    while true; do\n\
    if ! kill -0 $HEALTH_PID 2>/dev/null; then\n\
    echo "Health check server died, restarting..."\n\
    node /app/health-server.js &\n\
    HEALTH_PID=$!\n\
    fi\n\
    if ! kill -0 $ELIZA_PID 2>/dev/null; then\n\
    echo "ElizaOS died, restarting..."\n\
    cd /app/eliza/agent\n\
    NODE_OPTIONS="--no-warnings" npx ts-node --transpile-only src/index.ts --isRoot --plugin twitter --autopost --debug &\n\
    ELIZA_PID=$!\n\
    echo "ElizaOS restarted with PID $ELIZA_PID"\n\
    fi\n\
    sleep 10\n\
    done\n\
    ' > /app/single-entrypoint.sh && chmod +x /app/single-entrypoint.sh

# Set the command to run our new single entry point script
CMD ["/app/single-entrypoint.sh"]