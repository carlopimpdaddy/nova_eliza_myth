# Use a specific Node.js version for better reproducibility
FROM node:20-slim AS builder

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

# Build packages only (skip agent TypeScript compilation)
RUN pnpm run build && pnpm prune --prod

# Ensure ts-node is installed in the agent directory
RUN cd /app/agent && pnpm add ts-node typescript @types/node tslib

# Create a simple health check endpoint for the agent
RUN mkdir -p /app/agent/public && \
    echo '{"status":"ok"}' > /app/agent/public/health.json

# Create a simple JS bootstrap file
RUN echo 'const { execSync } = require("child_process");\n\ntry {\n  console.log("Starting ElizaOS Agent...");\n  execSync("cd /app && pnpm --filter \\"@elizaos/agent\\" start --isRoot", { stdio: "inherit" });\n} catch (error) {\n  console.error("Failed to start agent:", error);\n  process.exit(1);\n}' > /app/bootstrap.js

# Final runtime image
FROM node:20-slim

# Install runtime dependencies
RUN npm install -g pnpm@9.15.4 && \
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
COPY --from=builder /app/lerna.json ./
COPY --from=builder /app/packages ./packages
COPY --from=builder /app/scripts ./scripts
COPY --from=builder /app/characters ./characters
COPY --from=builder /app/bootstrap.js ./bootstrap.js

# Set environment variables for Railway
ENV NODE_ENV=production
ENV PORT=3000
ENV TS_NODE_TRANSPILE_ONLY=true

# Expose port
EXPOSE 3000

# Health check for Railway
HEALTHCHECK --interval=5s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health.json || exit 1

# Start the agent using the bootstrap script
CMD ["node", "bootstrap.js"]