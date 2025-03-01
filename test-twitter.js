const { TwitterApi } = require('twitter-api-v2');

// Log all environment variables for debugging
console.log('All Twitter-related environment variables:');
Object.keys(process.env)
  .filter(key => key.includes('TWITTER'))
  .forEach(key => {
    console.log(`${key}: ${process.env[key] ? 'SET' : 'NOT SET'}`);
  });

async function testTwitter() {
  try {
    console.log('Testing Twitter API connection...');
    
    // Check for required environment variables
    const apiKey = process.env.TWITTER_API_KEY;
    const apiSecret = process.env.TWITTER_API_SECRET;
    const accessToken = process.env.TWITTER_ACCESS_TOKEN;
    const accessSecret = process.env.TWITTER_ACCESS_SECRET;

    // Verify all credentials are present
    if (!apiKey || !apiSecret || !accessToken || !accessSecret) {
      console.error('Missing Twitter credentials. Required variables:');
      console.error(`TWITTER_API_KEY: ${apiKey ? 'SET' : 'NOT SET'}`);
      console.error(`TWITTER_API_SECRET: ${apiSecret ? 'SET' : 'NOT SET'}`);
      console.error(`TWITTER_ACCESS_TOKEN: ${accessToken ? 'SET' : 'NOT SET'}`);
      console.error(`TWITTER_ACCESS_SECRET: ${accessSecret ? 'SET' : 'NOT SET'}`);
      return;
    }

    // Create Twitter client
    const twitterClient = new TwitterApi({
      appKey: apiKey,
      appSecret: apiSecret,
      accessToken: accessToken,
      accessSecret: accessSecret,
    });

    // Verify credentials
    console.log('Verifying Twitter credentials...');
    const user = await twitterClient.v2.me();
    console.log(`Successfully authenticated as: ${user.data.username} (ID: ${user.data.id})`);
    
    // Post a test tweet
    console.log('Posting a test tweet...');
    const tweet = await twitterClient.v2.tweet('Testing ElizaOS Twitter integration at ' + new Date().toISOString());
    console.log(`Tweet posted successfully! ID: ${tweet.data.id}`);
    
    console.log('Twitter test completed successfully!');
  } catch (error) {
    console.error('Twitter test failed:', error);
  }
}

// Run the test
testTwitter(); 