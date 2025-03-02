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
RUN pnpm install --no-frozen-lockfile

# Build the project
RUN pnpm run build && pnpm prune --prod

# Final runtime image
FROM node:23.3.0-slim

# Install runtime dependencies
RUN npm install -g pnpm@9.15.4 concurrently && \
    apt-get update && \
    apt-get install -y \
    git \
    python3 \
    ffmpeg \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /app

# Copy built artifacts and production dependencies from the builder stage
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

# Set environment variables for Railway
ENV PORT=5173
ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV VITE_HOST=0.0.0.0
ENV HOST=0.0.0.0

# Create a simple API endpoint for health checks
RUN echo '{"status":"ok"}' > /app/client/public/health.json

# Expose ports - Railway uses PORT env var automatically
EXPOSE 5173 3000 8080

# Health check for Railway - check a static file endpoint
HEALTHCHECK --interval=5s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:5173/health.json || exit 1

# Create a custom start script for Railway
RUN echo '#!/bin/sh\ncd /app/client && pnpm run extract-version && exec vite --host 0.0.0.0 --port 5173' > /app/start-client.sh && \
    chmod +x /app/start-client.sh

# Start both agent and client
CMD ["sh", "-c", "concurrently \"pnpm start\" \"/app/start-client.sh\""]