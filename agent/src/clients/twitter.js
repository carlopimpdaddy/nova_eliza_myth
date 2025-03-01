// ElizaOS Twitter Client Implementation
const { TwitterApi } = require('twitter-api-v2');

/**
 * Creates a Twitter client for ElizaOS
 * @param {object} runtime - The ElizaOS runtime
 * @returns {object} Twitter client instance
 */
function createTwitterClient(runtime) {
  console.log('Initializing Twitter client for ElizaOS');
  
  // Check multiple possible environment variable names for Twitter credentials
  const apiKey = process.env.TWITTER_API_KEY;
  const apiSecret = process.env.TWITTER_API_SECRET || process.env.TWITTER_API_SECRET_KEY;
  const accessToken = process.env.TWITTER_ACCESS_TOKEN;
  const accessSecret = process.env.TWITTER_ACCESS_SECRET || process.env.TWITTER_ACCESS_TOKEN_SECRET;
  
  // Log credential status (without showing actual values)
  console.log('Twitter credentials status:');
  console.log(`TWITTER_API_KEY: ${apiKey ? 'SET' : 'NOT SET'}`);
  console.log(`TWITTER_API_SECRET: ${apiSecret ? 'SET' : 'NOT SET'}`);
  console.log(`TWITTER_ACCESS_TOKEN: ${accessToken ? 'SET' : 'NOT SET'}`);
  console.log(`TWITTER_ACCESS_SECRET: ${accessSecret ? 'SET' : 'NOT SET'}`);
  
  // Verify we have all required credentials
  if (!apiKey || !apiSecret || !accessToken || !accessSecret) {
    console.error('Missing Twitter API credentials. Twitter client cannot be initialized.');
    console.error('Please set all required Twitter credentials in Railway environment variables.');
    return null;
  }
  
  try {
    // Create Twitter client
    const client = new TwitterApi({
      appKey: apiKey,
      appSecret: apiSecret,
      accessToken: accessToken,
      accessSecret: accessSecret,
    });
    
    // Create the Twitter client object with ElizaOS-compatible interface
    const twitterClient = {
      // Client name property
      name: 'twitter',
      
      // Store API client instance
      client: client,
      
      // Method to post a tweet
      tweet: async (message) => {
        try {
          console.log(`Posting tweet: ${message}`);
          const result = await client.v2.tweet(message);
          console.log(`Tweet posted successfully. ID: ${result.data.id}`);
          return result;
        } catch (error) {
          console.error('Error posting tweet:', error);
          throw error;
        }
      },
      
      // Auto-post method for scheduled tweets
      autopost: async () => {
        try {
          // Generate tweet content
          const content = await runtime.generate('Write a brief, insightful tweet about startups, tech, or venture capital.');
          console.log(`Generated autopost content: ${content}`);
          return await twitterClient.tweet(content);
        } catch (error) {
          console.error('Error during autopost:', error);
          throw error;
        }
      },
      
      // Method to verify credentials and connection
      verifyCredentials: async () => {
        try {
          const userClient = client.readWrite;
          const user = await userClient.v2.me();
          console.log(`Twitter credentials verified successfully for user: ${user.data.username}`);
          return true;
        } catch (error) {
          console.error('Twitter credentials verification failed:', error);
          return false;
        }
      },
      
      // Get name method (required by ElizaOS client interface)
      getName: () => 'twitter'
    };
    
    // Verify credentials on startup
    twitterClient.verifyCredentials()
      .then(valid => {
        if (valid) {
          console.log('Twitter client initialized and ready to use');
          
          // Set up autoposting if configured
          if (process.env.TWITTER_AUTOPOST === 'true') {
            const interval = parseInt(process.env.TWITTER_AUTOPOST_INTERVAL || '60', 10) * 60 * 1000;
            console.log(`Setting up Twitter autoposting every ${interval/60000} minutes`);
            
            // Post first tweet after 2 minutes
            setTimeout(() => {
              twitterClient.autopost()
                .then(() => console.log('Initial autopost completed'))
                .catch(err => console.error('Initial autopost failed:', err));
            }, 2 * 60 * 1000);
            
            // Then set up regular interval
            setInterval(() => {
              twitterClient.autopost()
                .then(() => console.log('Scheduled autopost completed'))
                .catch(err => console.error('Scheduled autopost failed:', err));
            }, interval);
          }
        } else {
          console.warn('Twitter client created but credentials verification failed');
        }
      })
      .catch(error => {
        console.error('Error during Twitter client initialization:', error);
      });
    
    console.log('Twitter client created and initialized');
    return twitterClient;
  } catch (error) {
    console.error('Error creating Twitter client:', error);
    return null;
  }
}

module.exports = createTwitterClient; 