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
    npm install -g pnpm@9.15.4

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

# Make sure scripts are executable
RUN chmod +x /app/start.sh

# Install dependencies for health server using npm (not pnpm)
RUN npm install --production

# Create eliza directory for application
RUN mkdir -p /app/eliza

# Copy the application code to eliza directory
COPY . /app/eliza/

# Build the ElizaOS application
WORKDIR /app/eliza
RUN if [ -f "package.json" ]; then \
    pnpm install && \
    NODE_OPTIONS="--no-warnings" pnpm run build || echo "Build failed, but continuing"; \
    fi

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

# Set the command to run the entry point script
CMD ["node", "/app/agent/dist/index.js"]