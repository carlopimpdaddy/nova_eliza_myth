// ElizaOS Twitter Plugin
const path = require('path');

/**
 * Twitter plugin for ElizaOS
 * This plugin enables Twitter integration for the ElizaOS agent
 */
module.exports = {
  name: 'twitter',
  description: 'Twitter integration for ElizaOS',
  version: '1.0.0',
  
  // Define commands available to users
  commands: {
    tweet: {
      description: 'Post a tweet',
      usage: '/tweet [message]',
      handler: async (runtime, args) => {
        try {
          const message = args.join(' ');
          if (!message) {
            return 'Please provide a message to tweet';
          }
          
          const client = runtime.clients.twitter;
          if (!client) {
            return 'Twitter client is not available';
          }
          
          const result = await client.tweet(message);
          return `Tweet posted successfully! ID: ${result.data.id}`;
        } catch (error) {
          console.error('Error handling tweet command:', error);
          return `Error posting tweet: ${error.message}`;
        }
      }
    }
  },
  
  // Plugin configuration
  config: {
    // Enable automatic tweeting
    autopost: process.env.TWITTER_AUTOPOST === 'true',
    
    // Interval in minutes between automatic tweets
    interval: parseInt(process.env.TWITTER_AUTOPOST_INTERVAL || '60', 10),
    
    // Twitter API credentials from environment variables
    credentials: {
      apiKey: process.env.TWITTER_API_KEY,
      apiSecret: process.env.TWITTER_API_SECRET || process.env.TWITTER_API_SECRET_KEY,
      accessToken: process.env.TWITTER_ACCESS_TOKEN,
      accessSecret: process.env.TWITTER_ACCESS_SECRET || process.env.TWITTER_ACCESS_TOKEN_SECRET
    }
  },
  
  // Plugin initialization
  initialize: function(runtime) {
    console.log('Initializing Twitter plugin');
    
    // Verify that we have all required credentials
    const { apiKey, apiSecret, accessToken, accessSecret } = this.config.credentials;
    if (!apiKey || !apiSecret || !accessToken || !accessSecret) {
      console.error('Missing Twitter credentials. Twitter plugin will not be enabled.');
      return false;
    }
    
    // Register Twitter client
    try {
      // Load Twitter client
      const twitterClientPath = path.resolve(__dirname, '../src/clients/twitter.js');
      console.log(`Loading Twitter client from: ${twitterClientPath}`);
      
      const createTwitterClient = require(twitterClientPath);
      
      // Register client with runtime
      if (!runtime.clients.twitter) {
        console.log('Registering Twitter client with ElizaOS runtime');
        runtime.clients.twitter = createTwitterClient(runtime);
      } else {
        console.log('Twitter client already registered');
      }
      
      return true;
    } catch (error) {
      console.error('Error registering Twitter client:', error);
      return false;
    }
  },
  
  // Setup autoposting
  onStart: function(runtime) {
    console.log('Twitter plugin started');
    
    // Check if autopost is enabled
    if (this.config.autopost && runtime.clients.twitter) {
      console.log(`Twitter autoposting enabled with interval: ${this.config.interval} minutes`);
      
      // Initial autopost after 2 minutes
      setTimeout(() => {
        console.log('Executing initial Twitter autopost');
        if (runtime.clients.twitter && runtime.clients.twitter.autopost) {
          runtime.clients.twitter.autopost()
            .then(() => console.log('Initial autopost completed'))
            .catch(err => console.error('Initial autopost failed:', err));
        } else {
          console.error('Twitter client or autopost method not available');
        }
      }, 2 * 60 * 1000);
    } else {
      console.log('Twitter autoposting is disabled');
    }
  },
  
  // Client configuration
  clients: [
    {
      name: 'twitter',
      factory: (runtime) => {
        const clientPath = path.resolve(__dirname, '../src/clients/twitter.js');
        try {
          const createTwitterClient = require(clientPath);
          return createTwitterClient(runtime);
        } catch (error) {
          console.error(`Error loading Twitter client from ${clientPath}:`, error);
          return null;
        }
      }
    }
  ]
}; 