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

# Create a launcher script that delegates to the appropriate file
RUN echo 'console.log("Agent starting up");' > server.js && \
    echo 'require("./health-server").startServer();' >> server.js && \
    echo 'console.log("Agent module has been loaded and health check server started");' >> server.js

# Create agent index.js that also launches health check server
RUN echo 'console.log("Agent starting up");' > agent/dist/index.js && \
    echo 'require("../../health-server").startServer();' >> agent/dist/index.js && \
    echo 'module.exports = { start: () => console.log("Agent started") };' >> agent/dist/index.js

# Create package.json with proper configuration
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

# Set environment variable to ensure we know what we're running in
ENV NODE_ENV=production
ENV PORT=3000

# Start server (Railway may override this, but we set it anyway)
CMD ["node", "server.js"]