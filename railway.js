// Railway.js - ElizaOS entry point for Railway deployment
// This file provides a compatible entry point without requiring ts-node

const express = require('express');
const { spawn } = require('child_process');
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

// Patch defaultCharacter.ts to enable Twitter if it exists
try {
  const characterFiles = [
    'agent/src/defaultCharacter.ts', 
    'agent/dist/defaultCharacter.js'
  ];
  
  characterFiles.forEach(file => {
    if (fs.existsSync(file)) {
      console.log(`Found character file: ${file}`);
      let content = fs.readFileSync(file, 'utf8');
      
      // Simple string replacements to enable Twitter
      if (!content.includes('"twitter"')) {
        content = content.replace(/plugins: *\[([^\]]*)\]/, 'plugins: [$1"twitter"]');
        content = content.replace(/clients: *\[([^\]]*)\]/, 'clients: [$1"twitter"]');
        
        // Add pluginOptions if not present
        if (!content.includes('pluginOptions')) {
          content = content.replace(/plugins: *\[([^\]]*)\]/, 'plugins: [$1], pluginOptions: { twitter: { autopost: true, interval: 60 } }');
        }
        
        fs.writeFileSync(file, content);
        console.log(`Patched ${file} for Twitter support`);
      } else {
        console.log(`${file} already has Twitter configured`);
      }
    }
  });
} catch (error) {
  console.error('Error patching character files:', error);
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

// Start ElizaOS with Twitter plugin
console.log('Starting ElizaOS...');

// Function to start ElizaOS in the most compatible way
function startElizaOS() {
  // Determine the best method to start ElizaOS
  if (fs.existsSync('dist/index.js')) {
    console.log('Starting from compiled JS (dist/index.js)');
    require('./dist/index.js');
  } else if (fs.existsSync('agent/dist/index.js')) {
    console.log('Starting from agent dist folder');
    require('./agent/dist/index.js');
  } else {
    console.log('No compiled version found, running with npm/pnpm');
    
    // Check for pnpm
    try {
      // Try running the start script with pnpm
      const elizaProcess = spawn('pnpm', ['start', '--isRoot', '--plugin', 'twitter', '--autopost'], {
        stdio: 'inherit',
        env: process.env
      });
      
      elizaProcess.on('error', (err) => {
        console.error('Failed to start ElizaOS with pnpm:', err);
        console.log('Trying npm instead...');
        
        // Fall back to npm
        const npmProcess = spawn('npm', ['run', 'start', '--', '--isRoot', '--plugin', 'twitter', '--autopost'], {
          stdio: 'inherit',
          env: process.env
        });
        
        npmProcess.on('error', (err) => {
          console.error('Failed to start ElizaOS with npm:', err);
        });
      });
    } catch (error) {
      console.error('Error starting ElizaOS:', error);
    }
  }
}

// Start ElizaOS after a short delay to ensure health check server is running
setTimeout(startElizaOS, 1000);

// Export the app for potential testing
module.exports = app; 