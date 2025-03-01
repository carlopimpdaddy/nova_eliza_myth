# Use a specific Node.js version for better reproducibility
FROM node:23.3.0-slim AS builder

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
    libtool-bin \
    autoconf \
    automake \
    libopus-dev \
    make \
    g++ \
    build-essential \
    libcairo2-dev \
    libjpeg-dev \
    libpango1.0-dev \
    libgif-dev \
    openssl \
    libssl-dev libsecret-1-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Python 3 as the default python
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Set the working directory
WORKDIR /app

# Copy application code
COPY . .

# Install dependencies
RUN pnpm install

ENV DOCKER_BUILDKIT=1
ENV COMPOSE_DOCKER_CLI_BUILD=1

# Build the project
RUN pnpm run build && pnpm prune --prod

# List contents of important directories for debugging
RUN ls -la /app || true
RUN mkdir -p /app/dist /app/agent/dist
RUN touch /app/dist/.keep /app/agent/dist/.keep
RUN ls -la /app/agent/dist || true
RUN ls -la /app/dist || true

# Production stage
FROM node:23.3.0-slim

# Install runtime dependencies
RUN npm install -g pnpm@9.15.4 && \
    apt-get update && \
    apt-get install -y \
    git \
    python3 \
    ffmpeg \
    curl \
    procps \
    net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Create necessary directories
RUN mkdir -p ./dist

# Copy built artifacts and production dependencies from the builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./
COPY --from=builder /app/pnpm-workspace.yaml ./
COPY --from=builder /app/.npmrc ./
COPY --from=builder /app/turbo.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/agent ./agent
COPY --from=builder /app/client ./client
COPY --from=builder /app/lerna.json ./
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/characters ./characters

# Expose necessary ports
EXPOSE 3000

# Add environment variables to ensure proper network binding
ENV HOST=0.0.0.0
ENV PORT=3000

# Add a healthcheck to help with debugging
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/ || curl -f http://127.0.0.1:3000/ || exit 1

# Create a startup script with more debugging
RUN echo '#!/bin/sh\n\
    set -e\n\
    echo "Starting application..."\n\
    ls -la /app\n\
    echo "Node version: $(node -v)"\n\
    echo "NPM version: $(npm -v)"\n\
    echo "PNPM version: $(pnpm -v)"\n\
    echo "Network interfaces:"\n\
    ip addr || ifconfig || echo "No network tools available"\n\
    echo "Environment variables:"\n\
    env | grep -v PASSWORD | grep -v SECRET | grep -v KEY\n\
    echo "Starting services..."\n\
    (pnpm start > /app/server.log 2>&1 & echo $! > /app/server.pid) && \
    (pnpm start:client > /app/client.log 2>&1 & echo $! > /app/client.pid) && \
    sleep 5 && \
    echo "Process status:" && \
    ps aux | grep node && \
    echo "Checking if services are running:" && \
    if [ -f /app/server.pid ]; then echo "Server PID: $(cat /app/server.pid)"; else echo "Server not running"; fi && \
    if [ -f /app/client.pid ]; then echo "Client PID: $(cat /app/client.pid)"; else echo "Client not running"; fi && \
    echo "Server log:" && \
    tail -n 20 /app/server.log && \
    echo "Client log:" && \
    tail -n 20 /app/client.log && \
    echo "Waiting for services..." && \
    wait\n' > /app/start.sh && \
    chmod +x /app/start.sh

# Command to start the application
CMD ["/app/start.sh"]
