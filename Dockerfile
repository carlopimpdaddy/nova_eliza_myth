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

# Create simple health check app with Express
WORKDIR /healthapp
RUN npm init -y && \
    npm install express && \
    echo 'const express = require("express");' > index.js && \
    echo 'const app = express();' >> index.js && \
    echo 'const port = process.env.PORT || 3000;' >> index.js && \
    echo 'app.get("/health", (req, res) => {' >> index.js && \
    echo '  console.log("Health check request received");' >> index.js && \
    echo '  res.status(200).json({ status: "ok" });' >> index.js && \
    echo '});' >> index.js && \
    echo 'app.get("*", (req, res) => {' >> index.js && \
    echo '  console.log("Request received:", req.url);' >> index.js && \
    echo '  res.status(200).send("Service is running");' >> index.js && \
    echo '});' >> index.js && \
    echo 'app.listen(port, "0.0.0.0", () => {' >> index.js && \
    echo '  console.log(`Server running on port ${port}`);' >> index.js && \
    echo '});' >> index.js

# Final image
FROM node:18-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy health check app
COPY --from=builder /healthapp /app

# Expose port
EXPOSE 3000

# Start health check server
CMD ["node", "index.js"]