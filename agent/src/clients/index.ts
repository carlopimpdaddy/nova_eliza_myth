import createTwitterClient from './twitter';

export const clientFactories: Record<string, ClientFactory> = {
  twitter: createTwitterClient,
}; 