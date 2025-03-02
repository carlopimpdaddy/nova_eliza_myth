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

# Fix the character.ts file by removing the problematic 'extends' syntax error on line 842
RUN sed -i '842s/extends/\/\/ extends/' ./src/character.ts

# Now build the project with the fixed file
RUN pnpm build

# Create health check endpoint
RUN mkdir -p /app/public && \
    echo '{"status":"ok"}' > /app/public/health.json

# Set permissions
RUN mkdir -p /app/dist && \
    chown -R node:node /app && \
    chmod -R 755 /app

# Switch to node user
USER node

# Create a new stage for the final image
FROM node:23.3.0-slim

# Install runtime dependencies
RUN npm install -g pnpm@9.15.1 && \
    apt-get update && \
    apt-get install -y git python3 curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built artifacts and production dependencies from the builder stage
COPY --from=builder /app/package.json /app/
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/public /app/public

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Expose port
EXPOSE 3000

# Health check for Railway
HEALTHCHECK --interval=5s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health.json || exit 1

# Set the command to run the application (using built files)
CMD ["pnpm", "start", "--non-interactive"]