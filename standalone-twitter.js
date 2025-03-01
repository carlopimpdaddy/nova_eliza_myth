// Standalone Twitter client for ElizaOS deployments
// This file provides Twitter functionality even if the main app fails to start

const TwitterApi = require('twitter-api-v2').TwitterApi;

// Log startup information
console.log(`Starting standalone Twitter client at ${new Date().toISOString()}`);
console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);

// Log Twitter environment variables
console.log('Twitter environment variables:');
console.log(`TWITTER_API_KEY: ${process.env.TWITTER_API_KEY ? 'SET' : 'NOT SET'}`);
console.log(`TWITTER_API_SECRET: ${process.env.TWITTER_API_SECRET ? 'SET' : 'NOT SET'}`);
console.log(`TWITTER_ACCESS_TOKEN: ${process.env.TWITTER_ACCESS_TOKEN ? 'SET' : 'NOT SET'}`);
console.log(`TWITTER_ACCESS_SECRET: ${process.env.TWITTER_ACCESS_SECRET ? 'SET' : 'NOT SET'}`);

// Check if all required Twitter variables are present
const requiredVars = ['TWITTER_API_KEY', 'TWITTER_API_SECRET', 'TWITTER_ACCESS_TOKEN', 'TWITTER_ACCESS_SECRET'];
const missingVars = requiredVars.filter(key => !process.env[key]);

if (missingVars.length > 0) {
  console.error(`Missing Twitter variables: ${missingVars.join(', ')}`);
  console.error('Twitter client cannot start without these variables');
  process.exit(1);
}

// Create Twitter client
const twitterClient = new TwitterApi({
  appKey: process.env.TWITTER_API_KEY,
  appSecret: process.env.TWITTER_API_SECRET,
  accessToken: process.env.TWITTER_ACCESS_TOKEN,
  accessSecret: process.env.TWITTER_ACCESS_SECRET,
});

// Sample post examples from Nova 11 Wing
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
    
    console.log(`Posting tweet: ${tweetText}`);
    const result = await twitterClient.v2.tweet(tweetText);
    console.log(`Tweet posted successfully! ID: ${result.data.id}`);
    
    return true;
  } catch (error) {
    console.error('Error posting tweet:', error);
    return false;
  }
}

// Verify credentials and start posting
async function verifyAndStart() {
  try {
    console.log('Verifying Twitter credentials...');
    const user = await twitterClient.v2.me();
    console.log(`Successfully authenticated as: ${user.data.username} (ID: ${user.data.id})`);
    
    // Post initial tweet
    await postRandomTweet();
    
    // Set up interval for posting (every 60 minutes)
    const intervalMinutes = parseInt(process.env.TWITTER_AUTOPOST_INTERVAL || '60', 10);
    console.log(`Setting up autoposting every ${intervalMinutes} minutes`);
    setInterval(postRandomTweet, intervalMinutes * 60 * 1000);
    
    console.log('Standalone Twitter client is running...');
  } catch (error) {
    console.error('Twitter verification failed:', error);
  }
}

// Start the standalone client
verifyAndStart(); 