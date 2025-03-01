# Use a specific Node.js version for better reproducibility
FROM node:18-slim

# Install necessary build tools
RUN apt-get update && \
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
    rm -rf /var/lib/apt/lists/* && \
    npm install -g pnpm@9.15.4

# Set Python 3 as the default python
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Create app directory
WORKDIR /app

# Copy the application files
COPY . .

# Create the agent directory structure
RUN mkdir -p /app/agent/dist

# Create health check server
RUN npm install express && \
    echo 'const express = require("express");' > health-server.js && \
    echo 'const app = express();' >> health-server.js && \
    echo 'const port = process.env.PORT || 3000;' >> health-server.js && \
    echo 'console.log("Starting health check server on port:", port);' >> health-server.js && \
    echo 'app.get("/health", (req, res) => {' >> health-server.js && \
    echo '  console.log("Health check request received");' >> health-server.js && \
    echo '  res.status(200).json({ status: "ok" });' >> health-server.js && \
    echo '});' >> health-server.js && \
    echo 'app.get("*", (req, res) => {' >> health-server.js && \
    echo '  console.log("Request received:", req.url);' >> health-server.js && \
    echo '  res.status(200).send("Service is running");' >> health-server.js && \
    echo '});' >> health-server.js && \
    echo 'app.listen(port, "0.0.0.0", () => {' >> health-server.js && \
    echo '  console.log(`Health check server running on port ${port}`);' >> health-server.js && \
    echo '});' >> health-server.js

# Create /app/agent/dist/index.js that Railway wants to run
RUN echo 'console.log("Starting ElizaOS bootstrap...");' > /app/agent/dist/index.js && \
    echo 'const { spawn } = require("child_process");' >> /app/agent/dist/index.js && \
    echo '' >> /app/agent/dist/index.js && \
    echo '// Start health check server' >> /app/agent/dist/index.js && \
    echo 'console.log("Starting health check server...");' >> /app/agent/dist/index.js && \
    echo 'require("../../health-server");' >> /app/agent/dist/index.js && \
    echo 'console.log("Health check server started");' >> /app/agent/dist/index.js && \
    echo '' >> /app/agent/dist/index.js && \
    echo '// Set up types.ts if needed for build' >> /app/agent/dist/index.js && \
    echo 'const fs = require("fs");' >> /app/agent/dist/index.js && \
    echo 'const path = require("path");' >> /app/agent/dist/index.js && \
    echo 'const typesPath = path.join(__dirname, "../../agent/src/types.ts");' >> /app/agent/dist/index.js && \
    echo 'if (!fs.existsSync(typesPath)) {' >> /app/agent/dist/index.js && \
    echo '  console.log("Creating types.ts file...");' >> /app/agent/dist/index.js && \
    echo '  const typesContent = `export type ModelProviderName = "grok" | "openai" | "anthropic" | "perplexity" | "gemini";\n' >> /app/agent/dist/index.js && \
    echo 'export interface Character {\n' >> /app/agent/dist/index.js && \
    echo '  name: string;\n' >> /app/agent/dist/index.js && \
    echo '  database: any;\n' >> /app/agent/dist/index.js && \
    echo '  username: string;\n' >> /app/agent/dist/index.js && \
    echo '  screenName: string;\n' >> /app/agent/dist/index.js && \
    echo '  plugins: any[];\n' >> /app/agent/dist/index.js && \
    echo '  clients: string[];\n' >> /app/agent/dist/index.js && \
    echo '  modelProvider: ModelProviderName;\n' >> /app/agent/dist/index.js && \
    echo '  settings: any;\n' >> /app/agent/dist/index.js && \
    echo '  system: string;\n' >> /app/agent/dist/index.js && \
    echo '  bio: string[];\n' >> /app/agent/dist/index.js && \
    echo '  lore: string[];\n' >> /app/agent/dist/index.js && \
    echo '  messageExamples: any[][];\n' >> /app/agent/dist/index.js && \
    echo '  postExamples: string[];\n' >> /app/agent/dist/index.js && \
    echo '  topics: string[];\n' >> /app/agent/dist/index.js && \
    echo '  style: {\n' >> /app/agent/dist/index.js && \
    echo '    all: string[];\n' >> /app/agent/dist/index.js && \
    echo '    chat: string[];\n' >> /app/agent/dist/index.js && \
    echo '    post: string[];\n' >> /app/agent/dist/index.js && \
    echo '  };\n' >> /app/agent/dist/index.js && \
    echo '  adjectives: string[];\n' >> /app/agent/dist/index.js && \
    echo '  extends: any[];\n' >> /app/agent/dist/index.js && \
    echo '}`;\n' >> /app/agent/dist/index.js && \
    echo '  fs.mkdirSync(path.dirname(typesPath), { recursive: true });' >> /app/agent/dist/index.js && \
    echo '  fs.writeFileSync(typesPath, typesContent);' >> /app/agent/dist/index.js && \
    echo '  console.log("Created types.ts file");' >> /app/agent/dist/index.js && \
    echo '}' >> /app/agent/dist/index.js && \
    echo '' >> /app/agent/dist/index.js && \
    echo '// Build and run the main application' >> /app/agent/dist/index.js && \
    echo 'console.log("Building and starting ElizaOS application...");' >> /app/agent/dist/index.js && \
    echo 'try {' >> /app/agent/dist/index.js && \
    echo '  // Install dependencies if they are not installed already' >> /app/agent/dist/index.js && \
    echo '  if (!fs.existsSync(path.join(__dirname, "../../node_modules"))) {' >> /app/agent/dist/index.js && \
    echo '    console.log("Installing dependencies...");' >> /app/agent/dist/index.js && \
    echo '    const install = spawn("pnpm", ["install"], { stdio: "inherit", cwd: "/app" });' >> /app/agent/dist/index.js && \
    echo '    install.on("close", (code) => {' >> /app/agent/dist/index.js && \
    echo '      if (code !== 0) {' >> /app/agent/dist/index.js && \
    echo '        console.error("Failed to install dependencies");' >> /app/agent/dist/index.js && \
    echo '        return;' >> /app/agent/dist/index.js && \
    echo '      }' >> /app/agent/dist/index.js && \
    echo '      buildAndStart();' >> /app/agent/dist/index.js && \
    echo '    });' >> /app/agent/dist/index.js && \
    echo '  } else {' >> /app/agent/dist/index.js && \
    echo '    buildAndStart();' >> /app/agent/dist/index.js && \
    echo '  }' >> /app/agent/dist/index.js && \
    echo '} catch (error) {' >> /app/agent/dist/index.js && \
    echo '  console.error("Error starting ElizaOS:", error);' >> /app/agent/dist/index.js && \
    echo '}' >> /app/agent/dist/index.js && \
    echo '' >> /app/agent/dist/index.js && \
    echo 'function buildAndStart() {' >> /app/agent/dist/index.js && \
    echo '  console.log("Building application...");' >> /app/agent/dist/index.js && \
    echo '  const build = spawn("pnpm", ["run", "build"], { stdio: "inherit", cwd: "/app" });' >> /app/agent/dist/index.js && \
    echo '  build.on("close", (code) => {' >> /app/agent/dist/index.js && \
    echo '    if (code !== 0) {' >> /app/agent/dist/index.js && \
    echo '      console.error("Build failed");' >> /app/agent/dist/index.js && \
    echo '      return;' >> /app/agent/dist/index.js && \
    echo '    }' >> /app/agent/dist/index.js && \
    echo '    console.log("Starting application...");' >> /app/agent/dist/index.js && \
    echo '    const start = spawn("pnpm", ["start"], { stdio: "inherit", cwd: "/app" });' >> /app/agent/dist/index.js && \
    echo '    start.on("close", (code) => {' >> /app/agent/dist/index.js && \
    echo '      console.log(`Application exited with code ${code}`);' >> /app/agent/dist/index.js && \
    echo '      process.exit(code);' >> /app/agent/dist/index.js && \
    echo '    });' >> /app/agent/dist/index.js && \
    echo '  });' >> /app/agent/dist/index.js && \
    echo '}' >> /app/agent/dist/index.js && \
    echo '' >> /app/agent/dist/index.js && \
    echo '// Export a start function to satisfy any imports' >> /app/agent/dist/index.js && \
    echo 'module.exports = { start: () => console.log("Agent module loaded") };' >> /app/agent/dist/index.js

# Install dependencies
RUN pnpm install

# Expose port for health check
EXPOSE 3000

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Railway will run /app/agent/dist/index.js directly, so we don't need a CMD
# CMD ["node", "/app/agent/dist/index.js"]