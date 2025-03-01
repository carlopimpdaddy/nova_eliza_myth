// Railway.js - ElizaOS entry point for Railway deployment
// This file provides a compatible entry point without requiring ts-node

const express = require('express');
const { spawn, execSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Create Express app for health checks
const app = express();
const port = process.env.PORT || 8080;

// Log startup information
console.log(`Starting ElizaOS Railway deployment at ${new Date().toISOString()}`);
console.log(`Working directory: ${process.cwd()}`);
console.log(`Node version: ${process.version}`);

// Configure Twitter environment variables
const twitterVars = {
  TWITTER_API_KEY: process.env.TWITTER_API_KEY,
  TWITTER_API_SECRET: process.env.TWITTER_API_SECRET_KEY || process.env.TWITTER_API_SECRET,
  TWITTER_ACCESS_TOKEN: process.env.TWITTER_ACCESS_TOKEN,
  TWITTER_ACCESS_SECRET: process.env.TWITTER_ACCESS_TOKEN_SECRET || process.env.TWITTER_ACCESS_SECRET,
  // Enable Twitter plugin
  ENABLE_PLUGINS: 'twitter',
  PLUGINS: 'twitter',
  ENABLE_TWITTER: 'true',
  TWITTER_ENABLED: 'true',
  TWITTER_AUTOPOST: 'true',
  TWITTER_AUTOPOST_INTERVAL: '60',
  // Debug settings
  DEBUG: 'twitter*,@elizaos/plugin-twitter*,@elizaos:*',
  LOG_LEVEL: 'debug',
  DISPLAY_NAME: 'Nova 11 Wing'
};

// Log Twitter environment variables
console.log('Twitter environment variables:');
Object.keys(twitterVars).forEach(key => {
  if (key.includes('KEY') || key.includes('SECRET') || key.includes('TOKEN')) {
    console.log(`${key}: ${twitterVars[key] ? 'SET' : 'NOT SET'}`);
  } else {
    console.log(`${key}: ${twitterVars[key]}`);
  }
  
  // Set the environment variable for child processes
  process.env[key] = twitterVars[key];
});

// Check if all required Twitter variables are present
const requiredTwitterVars = ['TWITTER_API_KEY', 'TWITTER_API_SECRET', 'TWITTER_ACCESS_TOKEN', 'TWITTER_ACCESS_SECRET'];
const missingVars = requiredTwitterVars.filter(key => !process.env[key]);

if (missingVars.length > 0) {
  console.warn(`Missing Twitter variables: ${missingVars.join(', ')}`);
  console.warn('Twitter functionality might not work correctly');
} else {
  console.log('All required Twitter variables are present');
}

// Create a .env file for ElizaOS
try {
  let envContent = '# Twitter API Credentials\n';
  Object.keys(twitterVars).forEach(key => {
    envContent += `${key}=${process.env[key] || ''}\n`;
  });
  
  // Write to project root and agent directory
  fs.writeFileSync('.env', envContent);
  
  if (fs.existsSync('agent')) {
    fs.writeFileSync(path.join('agent', '.env'), envContent);
    console.log('Created .env files for Twitter configuration');
  }
} catch (error) {
  console.error('Error creating .env files:', error);
}

// Health check endpoints
app.get('/health', (req, res) => {
  console.log(`Health check request received at ${new Date().toISOString()}`);
  res.status(200).json({ status: 'ok' });
});

app.get('/', (req, res) => {
  res.status(200).send('ElizaOS is running');
});

app.get('*', (req, res) => {
  console.log(`Request received: ${req.url}`);
  res.status(200).send('Service is running');
});

// Start the health check server
app.listen(port, '0.0.0.0', () => {
  console.log(`Health check server running on port ${port}`);
});

// Function to install necessary dependencies
function installDependencies() {
  try {
    console.log('Installing necessary dependencies...');
    
    // Install twitter-api-v2 globally to ensure it's available
    console.log('Installing twitter-api-v2...');
    execSync('npm install --no-save twitter-api-v2@^1.15.0', { stdio: 'inherit' });
    
    // Install ts-node globally to fix the ERR_MODULE_NOT_FOUND error
    console.log('Installing ts-node globally...');
    execSync('npm install -g ts-node', { stdio: 'inherit' });
    
    // Ensure the twitter client directory exists
    const twitterClientDir = path.join('agent', 'src', 'clients', 'twitter');
    if (!fs.existsSync(twitterClientDir)) {
      console.log(`Creating Twitter client directory: ${twitterClientDir}`);
      fs.mkdirSync(twitterClientDir, { recursive: true });
    }
    
    // Create TypeScript Twitter client if it doesn't exist
    const twitterClientFile = path.join(twitterClientDir, 'index.ts');
    if (!fs.existsSync(twitterClientFile)) {
      console.log(`Creating Twitter client file: ${twitterClientFile}`);
      const twitterClientContent = `import { TwitterApi } from 'twitter-api-v2';
import type { AgentRuntime } from '../../AgentRuntime';
import { Client } from '../Client';
import { logger } from '../../logger';

const log = logger.child({ module: 'TwitterClient' });

export class TwitterClient extends Client {
  private client: TwitterApi | null = null;
  private runtime: AgentRuntime;
  private tweetInterval: NodeJS.Timeout | null = null;
  private autopostEnabled: boolean = false;
  private intervalMinutes: number = 60;

  constructor(runtime: AgentRuntime) {
    super('twitter');
    this.runtime = runtime;
    log.info(\`Twitter client created for \${runtime.character.name}\`);
  }

  async init(): Promise<void> {
    try {
      log.info('Initializing Twitter client');
      
      // Check for required environment variables
      const apiKey = process.env.TWITTER_API_KEY;
      const apiSecret = process.env.TWITTER_API_SECRET;
      const accessToken = process.env.TWITTER_ACCESS_TOKEN;
      const accessSecret = process.env.TWITTER_ACCESS_SECRET;

      // Log available variables for debugging
      log.info('Twitter environment variables:');
      log.info(\`TWITTER_API_KEY: \${apiKey ? 'SET' : 'NOT SET'}\`);
      log.info(\`TWITTER_API_SECRET: \${apiSecret ? 'SET' : 'NOT SET'}\`);
      log.info(\`TWITTER_ACCESS_TOKEN: \${accessToken ? 'SET' : 'NOT SET'}\`);
      log.info(\`TWITTER_ACCESS_SECRET: \${accessSecret ? 'SET' : 'NOT SET'}\`);

      if (!apiKey || !apiSecret || !accessToken || !accessSecret) {
        log.error('Missing Twitter credentials. Twitter client will not be initialized.');
        return;
      }

      // Create the Twitter client
      this.client = new TwitterApi({
        appKey: apiKey,
        appSecret: apiSecret,
        accessToken: accessToken,
        accessSecret: accessSecret,
      });

      log.info('Twitter client initialized successfully');

      // Check if autopost is enabled from environment or character settings
      this.autopostEnabled = process.env.TWITTER_AUTOPOST === 'true' || 
        Boolean(this.runtime.character.pluginOptions?.twitter?.autopost);
      
      // Get interval from environment or character settings (default: 60 minutes)
      this.intervalMinutes = parseInt(process.env.TWITTER_AUTOPOST_INTERVAL || '60', 10) || 
        this.runtime.character.pluginOptions?.twitter?.interval || 60;

      log.info(\`Twitter autopost: \${this.autopostEnabled ? 'enabled' : 'disabled'}\`);
      log.info(\`Twitter autopost interval: \${this.intervalMinutes} minutes\`);

      if (this.autopostEnabled) {
        this.setupAutoposting();
      }

      // Test the credentials
      const verifyResult = await this.client.v2.me();
      log.info(\`Twitter credentials verified. User ID: \${verifyResult.data.id}, Username: \${verifyResult.data.username}\`);
    } catch (error) {
      log.error('Failed to initialize Twitter client:', error);
    }
  }

  private setupAutoposting(): void {
    log.info(\`Setting up autoposting every \${this.intervalMinutes} minutes\`);
    
    // Clear existing interval if any
    if (this.tweetInterval) {
      clearInterval(this.tweetInterval);
    }

    // Do an initial post after a short delay
    setTimeout(() => this.generateAndPost(), 30000);

    // Set up recurring posting
    this.tweetInterval = setInterval(() => {
      this.generateAndPost();
    }, this.intervalMinutes * 60 * 1000);
  }

  private async generateAndPost(): Promise<void> {
    try {
      if (!this.client) {
        log.error('Twitter client not initialized, cannot post tweet');
        return;
      }

      log.info('Generating tweet content');
      const tweetText = await this.generateTweetContent();
      
      if (!tweetText) {
        log.error('Failed to generate tweet content');
        return;
      }

      log.info(\`Posting tweet: \${tweetText}\`);
      const result = await this.client.v2.tweet(tweetText);
      log.info(\`Tweet posted successfully, ID: \${result.data.id}\`);
    } catch (error) {
      log.error('Failed to post tweet:', error);
    }
  }

  private async generateTweetContent(): Promise<string> {
    try {
      // Use the character's postExamples if available
      const { postExamples } = this.runtime.character;
      
      if (postExamples && postExamples.length > 0) {
        // Randomly select an example post
        const randomIndex = Math.floor(Math.random() * postExamples.length);
        return postExamples[randomIndex];
      }

      // If no examples, generate a simple message
      return \`Thoughts from \${this.runtime.character.name} (powered by ElizaOS): Technology is constantly evolving, just like our understanding of the world.\`;
    } catch (error) {
      log.error('Error generating tweet content:', error);
      return \`Thoughts from \${this.runtime.character.name}: Exploring ideas in this digital realm.\`;
    }
  }

  async tweet(message: string): Promise<void> {
    try {
      if (!this.client) {
        log.error('Twitter client not initialized, cannot post tweet');
        return;
      }

      log.info(\`Posting tweet: \${message}\`);
      const result = await this.client.v2.tweet(message);
      log.info(\`Tweet posted successfully, ID: \${result.data.id}\`);
    } catch (error) {
      log.error('Failed to post tweet:', error);
    }
  }

  getName(): string {
    return 'twitter';
  }
}

// Export a factory function to create a new TwitterClient
export default function createTwitterClient(runtime: AgentRuntime): Client {
  return new TwitterClient(runtime);
}`;
      
      fs.writeFileSync(twitterClientFile, twitterClientContent);
    }
    
    // Add Twitter client to clients index if needed
    const clientsIndexFile = path.join('agent', 'src', 'clients', 'index.ts');
    if (fs.existsSync(clientsIndexFile)) {
      let clientsContent = fs.readFileSync(clientsIndexFile, 'utf8');
      
      // Add import if it doesn't exist
      if (!clientsContent.includes("import createTwitterClient from './twitter'")) {
        clientsContent = "import createTwitterClient from './twitter';\n" + clientsContent;
      }
      
      // Add factory if it doesn't exist
      if (!clientsContent.includes('twitter: createTwitterClient')) {
        // Replace the clientFactories object
        if (clientsContent.includes('export const clientFactories')) {
          clientsContent = clientsContent.replace(
            /export const clientFactories[^{]*{([^}]*)}/,
            'export const clientFactories = {\n  twitter: createTwitterClient,$1}'
          );
        } else {
          // Add the clientFactories object if it doesn't exist
          clientsContent += '\nexport const clientFactories = {\n  twitter: createTwitterClient,\n};\n';
        }
      }
      
      fs.writeFileSync(clientsIndexFile, clientsContent);
      console.log('Updated clients index file to include Twitter client');
    }
    
    // Update agent package.json to include twitter-api-v2
    const agentPackageFile = path.join('agent', 'package.json');
    if (fs.existsSync(agentPackageFile)) {
      const packageJson = JSON.parse(fs.readFileSync(agentPackageFile, 'utf8'));
      
      // Add twitter-api-v2 if it doesn't exist
      if (!packageJson.dependencies['twitter-api-v2']) {
        packageJson.dependencies['twitter-api-v2'] = '^1.15.0';
        fs.writeFileSync(agentPackageFile, JSON.stringify(packageJson, null, 2));
        console.log('Added twitter-api-v2 dependency to agent package.json');
      }
    }
    
    // Patch defaultCharacter.ts to enable Twitter if it exists
    const characterFiles = [
      'agent/src/defaultCharacter.ts', 
      'agent/dist/defaultCharacter.js'
    ];
    
    characterFiles.forEach(file => {
      if (fs.existsSync(file)) {
        console.log(`Found character file: ${file}`);
        let content = fs.readFileSync(file, 'utf8');
        
        // Add Twitter to clients and plugins if not already present
        let modified = false;
        
        // Add Twitter to plugins array
        if (content.includes('plugins: [') && !content.includes('"twitter"')) {
          content = content.replace(/plugins: *\[([^\]]*)\]/, 'plugins: [$1"twitter", ]');
          modified = true;
        }
        
        // Add Twitter to clients array
        if (content.includes('clients: [') && !content.includes('"twitter"')) {
          content = content.replace(/clients: *\[([^\]]*)\]/, 'clients: [$1"twitter", ]');
          modified = true;
        }
        
        // Add pluginOptions if not present
        if (!content.includes('pluginOptions') && modified) {
          content = content.replace(/plugins: *\[([^\]]*)\]/, 'plugins: [$1], pluginOptions: { twitter: { autopost: true, interval: 60 } }');
        }
        
        if (modified) {
          fs.writeFileSync(file, content);
          console.log(`Patched ${file} for Twitter support`);
        } else {
          console.log(`${file} already has Twitter configured or couldn't be modified`);
        }
      }
    });
    
    return true;
  } catch (error) {
    console.error('Error installing dependencies:', error);
    return false;
  }
}

// Start ElizaOS with the appropriate approach based on the environment
function startElizaOS() {
  // First, install dependencies
  const dependenciesInstalled = installDependencies();
  
  console.log('Starting ElizaOS...');
  
  if (fs.existsSync('node_modules/.bin/pnpm')) {
    // Install with --no-frozen-lockfile to bypass the lockfile error
    try {
      console.log('Installing dependencies with --no-frozen-lockfile...');
      execSync('cd agent && npm install twitter-api-v2@^1.15.0 --no-save', { stdio: 'inherit' });
      
      // Create dedicated start-twitter.js script
      const startTwitterScript = `
// start-twitter.js - Bootstrap script for ElizaOS Twitter functionality
const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

console.log('Starting ElizaOS Twitter bootstrap...');

// Check for required environment variables
const apiKey = process.env.TWITTER_API_KEY;
const apiSecret = process.env.TWITTER_API_SECRET;
const accessToken = process.env.TWITTER_ACCESS_TOKEN;
const accessSecret = process.env.TWITTER_ACCESS_SECRET;

console.log('Twitter environment variables:');
console.log(\`TWITTER_API_KEY: \${apiKey ? 'SET' : 'NOT SET'}\`);
console.log(\`TWITTER_API_SECRET: \${apiSecret ? 'SET' : 'NOT SET'}\`);
console.log(\`TWITTER_ACCESS_TOKEN: \${accessToken ? 'SET' : 'NOT SET'}\`);
console.log(\`TWITTER_ACCESS_SECRET: \${accessSecret ? 'SET' : 'NOT SET'}\`);

// Load TwitterApi directly
const { TwitterApi } = require('twitter-api-v2');

// Create Twitter client if all credentials are present
if (apiKey && apiSecret && accessToken && accessSecret) {
  console.log('Creating Twitter client with provided credentials...');
  
  // Create the client
  const twitterClient = new TwitterApi({
    appKey: apiKey,
    appSecret: apiSecret,
    accessToken: accessToken,
    accessSecret: accessSecret,
  });
  
  // Post a test tweet
  async function postTweet() {
    try {
      // Verify credentials
      const user = await twitterClient.v2.me();
      console.log(\`Successfully connected to Twitter as: \${user.data.username} (ID: \${user.data.id})\`);
      
      // Post the tweet
      const tweetText = \`ElizaOS Nova 11 Wing is now active on Railway.com! #AI #ElizaOS \${new Date().toISOString()}\`;
      console.log(\`Posting tweet: \${tweetText}\`);
      
      const result = await twitterClient.v2.tweet(tweetText);
      console.log(\`Tweet posted successfully! ID: \${result.data.id}\`);
    } catch (error) {
      console.error('Error posting tweet:', error);
    }
  }
  
  // Post the tweet after a delay
  setTimeout(postTweet, 5000);
} else {
  console.error('Missing Twitter credentials. Cannot post test tweet.');
}

// Run regular ElizaOS as a separate process
console.log('Starting ElizaOS agent...');
try {
  if (fs.existsSync('node_modules/.bin/pnpm')) {
    // Use pnpm to start the agent
    spawn('node_modules/.bin/pnpm', ['--filter', '@elizaos/agent', 'start', '--isRoot'], {
      stdio: 'inherit',
      env: process.env
    });
  } else {
    // Use regular node to start the agent
    spawn('node', ['agent/src/index.js', '--isRoot'], {
      stdio: 'inherit',
      env: process.env
    });
  }
} catch (error) {
  console.error('Error starting ElizaOS agent:', error);
}
`;
      
      fs.writeFileSync('start-twitter.js', startTwitterScript);
      console.log('Created start-twitter.js bootstrap script');
      
      // Run the bootstrap script
      console.log('Starting ElizaOS with Twitter integration using bootstrap script...');
      spawn('node', ['start-twitter.js'], { 
        stdio: 'inherit',
        env: process.env
      });
    } catch (error) {
      console.error('Error installing dependencies or starting ElizaOS with pnpm:', error);
      
      // Fall back to standalone Twitter client
      console.log('Starting standalone Twitter client as fallback...');
      runStandaloneTwitterClient();
    }
  } else {
    console.log('PNPM not found, falling back to standalone Twitter client...');
    runStandaloneTwitterClient();
  }
}

// Run a standalone Twitter client if ElizaOS fails to start
function runStandaloneTwitterClient() {
  console.log('Running standalone Twitter client...');
  
  try {
    // Create a standalone Twitter client file
    const standaloneClientPath = 'standalone-twitter.js';
    const standaloneClientContent = `
const { TwitterApi } = require('twitter-api-v2');

// Log Twitter environment variables
console.log('Twitter environment variables:');
console.log(\`TWITTER_API_KEY: \${process.env.TWITTER_API_KEY ? 'SET' : 'NOT SET'}\`);
console.log(\`TWITTER_API_SECRET: \${process.env.TWITTER_API_SECRET ? 'SET' : 'NOT SET'}\`);
console.log(\`TWITTER_ACCESS_TOKEN: \${process.env.TWITTER_ACCESS_TOKEN ? 'SET' : 'NOT SET'}\`);
console.log(\`TWITTER_ACCESS_SECRET: \${process.env.TWITTER_ACCESS_SECRET ? 'SET' : 'NOT SET'}\`);

// Create Twitter client
const twitterClient = new TwitterApi({
  appKey: process.env.TWITTER_API_KEY,
  appSecret: process.env.TWITTER_API_SECRET,
  accessToken: process.env.TWITTER_ACCESS_TOKEN,
  accessSecret: process.env.TWITTER_ACCESS_SECRET,
});

// Sample post examples
const postExamples = [
  "AI should vibe with what humans want. Alignment and coordination, you know?",
  "We're on this crazy ride where memes, tech, and existential dread are writing the future in real-time. It's wild.",
  "If you could build anything you wanted, and money was not an object, what would you build?",
  "We're all missing that collective vibe. Let's build cool shit together and get rich doing it. Forget zero-sum, let's level up together",
  "The future's only lit if we're busting our asses to make it happen. No slacking!",
  "People fear agents like they fear god.",
  "The internet's this crazy playground. Keep it free, decentralized, and a lotta memes!",
  "AI is not here to boss you around. but helping understand everyones own weird selves better.",
  "Tech gets cheaper, humans stay pricey, but AI might make us all budget-friendly.",
  "Nova 11 Wing is now online and ready to explore ideas with you!",
  "Just deployed on Railway.com and feeling powerful. Let's build the future together!",
  "ElizaOS and Twitter combined? Now that's a powerful integration worth sharing."
];

// Post a tweet at regular intervals
async function postRandomTweet() {
  try {
    // Randomly select a tweet
    const randomIndex = Math.floor(Math.random() * postExamples.length);
    const tweetText = postExamples[randomIndex];
    
    console.log(\`Posting tweet: \${tweetText}\`);
    const result = await twitterClient.v2.tweet(tweetText);
    console.log(\`Tweet posted successfully! ID: \${result.data.id}\`);
    
    return true;
  } catch (error) {
    console.error('Error posting tweet:', error);
    return false;
  }
}

// Verify credentials
async function verifyAndStart() {
  try {
    console.log('Verifying Twitter credentials...');
    const user = await twitterClient.v2.me();
    console.log(\`Successfully authenticated as: \${user.data.username} (ID: \${user.data.id})\`);
    
    // Post initial tweet
    await postRandomTweet();
    
    // Set up interval for posting (every 60 minutes)
    console.log('Setting up autoposting every 60 minutes');
    setInterval(postRandomTweet, 60 * 60 * 1000);
    
    console.log('Standalone Twitter client is running...');
  } catch (error) {
    console.error('Twitter verification failed:', error);
  }
}

// Start the standalone client
verifyAndStart();
`;
    
    fs.writeFileSync(standaloneClientPath, standaloneClientContent);
    console.log(`Created standalone Twitter client at ${standaloneClientPath}`);
    
    // Execute the standalone client
    spawn('node', [standaloneClientPath], {
      stdio: 'inherit',
      env: process.env
    });
  } catch (error) {
    console.error('Error running standalone Twitter client:', error);
  }
}

// Start ElizaOS after a short delay to ensure health check server is running
setTimeout(startElizaOS, 1000);

// Export the app for potential testing
module.exports = app; 