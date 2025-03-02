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

# Create a new fixed character.ts file using Nova 11 Wing character
RUN echo 'import { type Character, ModelProviderName } from "@elizaos/core";\n\nexport { Character };\n\nexport const defaultCharacter: Character = {\n  name: "Nova 11 Wing",\n  username: "mythosbuild",\n  bio: "Startup founder mentor & advisor. Helping founders build successful startups. Ask me about team building, product strategy, fundraising, and scaling.",\n  lore: "Nova 11 Wing is an experienced startup founder who has built and sold multiple successful companies. She now mentors and advises early-stage founders.",\n  messageExamples: [],\n  postExamples: [],\n  personality: {\n    knowledgeable: true,\n    strategic: true,\n    supportive: true,\n    practical: true\n  },\n  modelProvider: "grok" as ModelProviderName,\n  plugins: ["@elizaos/plugin-twitter"],\n  clients: ["twitter"],\n  settings: {\n    twitter: {\n      commands: {\n        startup: {\n          description: "Get startup advice and guidance",\n          usage: "/startup [topic] e.g., team, product, market"\n        },\n        mentor: {\n          description: "Get personalized mentoring on specific challenges",\n          usage: "/mentor [challenge] e.g., hiring, scaling, fundraising"\n        },\n        feedback: {\n          description: "Get feedback on your startup plans or materials",\n          usage: "/feedback [area] e.g., pitch, strategy, product"\n        }\n      }\n    }\n  },\n  screenName: "Nova 11 Wing"\n};\n\n// Export character as alias to defaultCharacter for backward compatibility\nexport const character = defaultCharacter;' > ./src/character.ts

# Now build the project with the fixed file
RUN pnpm build

# Create health check endpoint
RUN mkdir -p /app/public && \
    echo '{"status":"ok"}' > /app/public/health.json

# Create a start script that skips Twitter client initialization if credentials aren't present
RUN echo '#!/bin/sh\n\n# Check if Twitter credentials are set\nif [ -z "$TWITTER_API_KEY" ] || [ -z "$TWITTER_API_SECRET" ] || [ -z "$TWITTER_ACCESS_TOKEN" ] || [ -z "$TWITTER_ACCESS_SECRET" ]; then\n  echo "WARNING: Twitter API credentials not set. Creating mock values to prevent crashes."\n  export TWITTER_API_KEY="mock_key"\n  export TWITTER_API_SECRET="mock_secret"\n  export TWITTER_ACCESS_TOKEN="mock_token"\n  export TWITTER_ACCESS_SECRET="mock_secret"\nfi\n\n# Start the application\nnode /app/dist/index.js\n' > /app/start.sh && \
    chmod +x /app/start.sh

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
COPY --from=builder /app/characters /app/characters
COPY --from=builder /app/start.sh /app/start.sh

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Set Twitter API environment variables with default values
# These will be overridden if provided by Railway
ENV TWITTER_API_KEY=mock_key
ENV TWITTER_API_SECRET=mock_secret
ENV TWITTER_ACCESS_TOKEN=mock_token
ENV TWITTER_ACCESS_SECRET=mock_secret

# Optional: Set other API keys with mock values
ENV OPENAI_API_KEY=sk-mock-key
ENV GROK_API_KEY=grok-mock-key

# Expose port
EXPOSE 3000

# Health check for Railway
HEALTHCHECK --interval=5s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:3000/health.json || exit 1

# Directly use the compiled JavaScript rather than the package.json scripts
CMD ["/app/start.sh"]