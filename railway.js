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

// Map Twitter environment variables to the names ElizaOS expects
console.log('Setting up Twitter environment variables...');
if (process.env.TWITTER_API_SECRET_KEY && !process.env.TWITTER_API_SECRET) {
  process.env.TWITTER_API_SECRET = process.env.TWITTER_API_SECRET_KEY;
  console.log('Mapped TWITTER_API_SECRET_KEY to TWITTER_API_SECRET');
}

if (process.env.TWITTER_ACCESS_TOKEN_SECRET && !process.env.TWITTER_ACCESS_SECRET) {
  process.env.TWITTER_ACCESS_SECRET = process.env.TWITTER_ACCESS_TOKEN_SECRET;
  console.log('Mapped TWITTER_ACCESS_TOKEN_SECRET to TWITTER_ACCESS_SECRET');
}

// Set additional Twitter environment variables
const twitterEnvVars = {
  ENABLE_PLUGINS: 'twitter',
  PLUGINS: 'twitter',
  ENABLE_TWITTER: 'true',
  TWITTER_ENABLED: 'true',
  TWITTER_AUTOPOST: 'true',
  TWITTER_AUTOPOST_INTERVAL: '60',
  DISPLAY_NAME: 'Nova 11 Wing',
  DEBUG: 'twitter*,@elizaos/plugin-twitter*,@elizaos:*',
  LOG_LEVEL: 'debug'
};

// Set the environment variables
Object.entries(twitterEnvVars).forEach(([key, value]) => {
  process.env[key] = value;
  console.log(`Set ${key}=${value}`);
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

// Create a .env file for ElizaOS with Twitter configuration
try {
  console.log('Creating .env file with Twitter configuration...');
  let envContent = '# Twitter API Credentials\n';
  
  // Add Twitter API credentials
  envContent += `TWITTER_API_KEY=${process.env.TWITTER_API_KEY || ''}\n`;
  envContent += `TWITTER_API_SECRET=${process.env.TWITTER_API_SECRET || ''}\n`;
  envContent += `TWITTER_ACCESS_TOKEN=${process.env.TWITTER_ACCESS_TOKEN || ''}\n`;
  envContent += `TWITTER_ACCESS_SECRET=${process.env.TWITTER_ACCESS_SECRET || ''}\n\n`;
  
  // Add Twitter plugin configuration
  envContent += '# Twitter Plugin Configuration\n';
  Object.entries(twitterEnvVars).forEach(([key, value]) => {
    envContent += `${key}=${value}\n`;
  });
  
  // Write to the main .env file
  fs.writeFileSync('.env', envContent);
  console.log('Created .env file in project root');
  
  // Also write to agent directory if it exists
  if (fs.existsSync('agent')) {
    fs.writeFileSync(path.join('agent', '.env'), envContent);
    console.log('Created .env file in agent directory');
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

// Function to install required dependencies
function installDependencies() {
  try {
    console.log('Ensuring required dependencies are installed...');
    
    // Install twitter-api-v2 if needed
    try {
      require('twitter-api-v2');
      console.log('twitter-api-v2 is already installed');
    } catch (error) {
      console.log('Installing twitter-api-v2...');
      execSync('npm install --no-save twitter-api-v2@^1.15.0', { stdio: 'inherit' });
    }
    
    return true;
  } catch (error) {
    console.error('Error installing dependencies:', error);
    return false;
  }
}

// Ensure client and plugin directories exist
function ensureTweetClientExists() {
  try {
    // Create plugin directories if they don't exist
    const dirs = [
      'agent/plugins',
      'agent/src/clients'
    ];
    
    dirs.forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
        console.log(`Created directory: ${dir}`);
      }
    });
    
    return true;
  } catch (error) {
    console.error('Error ensuring client directory:', error);
    return false;
  }
}

// Start ElizaOS with all Twitter configurations
function startElizaOS() {
  console.log('Starting ElizaOS...');
  
  // First install dependencies
  installDependencies();
  
  // Make sure Twitter client and plugin directories exist
  ensureTweetClientExists();
  
  // Determine the best way to start ElizaOS based on what's available
  let started = false;
  
  // Try with pnpm first if available
  if (fs.existsSync('node_modules/.bin/pnpm')) {
    try {
      console.log('Starting ElizaOS with pnpm...');
      const child = spawn('node_modules/.bin/pnpm', ['start', '--isRoot', '--plugin', 'twitter', '--autopost'], {
        stdio: 'inherit',
        env: process.env
      });
      started = true;
    } catch (error) {
      console.error('Error starting with pnpm:', error);
    }
  }
  
  // If that didn't work, try alternative methods
  if (!started && fs.existsSync('agent/dist/index.js')) {
    try {
      console.log('Starting ElizaOS from compiled code...');
      const child = spawn('node', ['agent/dist/index.js', '--isRoot', '--plugin', 'twitter', '--autopost'], {
        stdio: 'inherit',
        env: process.env
      });
      started = true;
    } catch (error) {
      console.error('Error starting from compiled code:', error);
    }
  }
  
  // Last resort: try with ts-node
  if (!started) {
    try {
      console.log('Starting ElizaOS with ts-node...');
      
      // Make sure ts-node is installed
      try {
        execSync('npm install -g ts-node', { stdio: 'inherit' });
      } catch (error) {
        console.warn('Failed to install ts-node globally, continuing anyway');
      }
      
      const child = spawn('ts-node', ['agent/src/index.ts', '--isRoot', '--plugin', 'twitter', '--autopost'], {
        stdio: 'inherit',
        env: process.env
      });
    } catch (error) {
      console.error('Error starting with ts-node:', error);
      console.error('All startup methods failed');
    }
  }
}

// Start everything
console.log('Initializing ElizaOS...');
setTimeout(startElizaOS, 2000);

// Export for potential testing
module.exports = app; 