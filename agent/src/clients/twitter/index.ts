import { TwitterApi } from 'twitter-api-v2';
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
    log.info(`Twitter client created for ${runtime.character.name}`);
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
      log.info(`TWITTER_API_KEY: ${apiKey ? 'SET' : 'NOT SET'}`);
      log.info(`TWITTER_API_SECRET: ${apiSecret ? 'SET' : 'NOT SET'}`);
      log.info(`TWITTER_ACCESS_TOKEN: ${accessToken ? 'SET' : 'NOT SET'}`);
      log.info(`TWITTER_ACCESS_SECRET: ${accessSecret ? 'SET' : 'NOT SET'}`);

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

      log.info(`Twitter autopost: ${this.autopostEnabled ? 'enabled' : 'disabled'}`);
      log.info(`Twitter autopost interval: ${this.intervalMinutes} minutes`);

      if (this.autopostEnabled) {
        this.setupAutoposting();
      }

      // Test the credentials
      const verifyResult = await this.client.v2.me();
      log.info(`Twitter credentials verified. User ID: ${verifyResult.data.id}, Username: ${verifyResult.data.username}`);
    } catch (error) {
      log.error('Failed to initialize Twitter client:', error);
    }
  }

  private setupAutoposting(): void {
    log.info(`Setting up autoposting every ${this.intervalMinutes} minutes`);
    
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

      log.info(`Posting tweet: ${tweetText}`);
      const result = await this.client.v2.tweet(tweetText);
      log.info(`Tweet posted successfully, ID: ${result.data.id}`);
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
      return `Thoughts from ${this.runtime.character.name} (powered by ElizaOS): Technology is constantly evolving, just like our understanding of the world.`;
    } catch (error) {
      log.error('Error generating tweet content:', error);
      return `Thoughts from ${this.runtime.character.name}: Exploring ideas in this digital realm.`;
    }
  }

  async tweet(message: string): Promise<void> {
    try {
      if (!this.client) {
        log.error('Twitter client not initialized, cannot post tweet');
        return;
      }

      log.info(`Posting tweet: ${message}`);
      const result = await this.client.v2.tweet(message);
      log.info(`Tweet posted successfully, ID: ${result.data.id}`);
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
} 