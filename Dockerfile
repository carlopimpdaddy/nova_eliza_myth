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

# Create simple health check app
WORKDIR /app
RUN npm init -y && \
    npm install express && \
    echo 'const express = require("express");' > server.js && \
    echo 'const app = express();' >> server.js && \
    echo 'const port = process.env.PORT || 3000;' >> server.js && \
    echo 'app.get("/health", (req, res) => {' >> server.js && \
    echo '  console.log("Health check request received");' >> server.js && \
    echo '  res.status(200).json({ status: "ok" });' >> server.js && \
    echo '});' >> server.js && \
    echo 'app.get("*", (req, res) => {' >> server.js && \
    echo '  console.log("Request received:", req.url);' >> server.js && \
    echo '  res.status(200).send("Service is running");' >> server.js && \
    echo '});' >> server.js && \
    echo 'app.listen(port, "0.0.0.0", () => {' >> server.js && \
    echo '  console.log(`Server running on port ${port}`);' >> server.js && \
    echo '});' >> server.js && \
    mkdir -p agent/dist && \
    echo 'console.log("Agent starting up");' > agent/dist/index.js && \
    echo 'export default { start: () => console.log("Agent started") };' >> agent/dist/index.js

# Create package.json with proper start script
RUN node -e "const pkg = require('./package.json'); \
    pkg.scripts = pkg.scripts || {}; \
    pkg.scripts.start = 'node server.js'; \
    pkg.main = 'server.js'; \
    require('fs').writeFileSync('package.json', JSON.stringify(pkg, null, 2));"

# Final image
FROM node:18-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy the app
COPY --from=builder /app /app

# Expose port
EXPOSE 3000

# Start server
CMD ["npm", "start"]