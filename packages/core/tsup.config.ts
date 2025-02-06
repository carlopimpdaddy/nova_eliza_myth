import { defineConfig } from "tsup";

export default defineConfig({
    entry: ["src/index.ts"],
    outDir: "dist",
    sourcemap: true,
    clean: true,
    format: ["esm"], // Ensure you're targeting CommonJS
    platform: "node",
    target: "node18",
    bundle: true,
    splitting: false,
    dts: true, // Generate declaration files
    external: [
        "@huggingface/transformers",
        "bignumber.js",
        "dotenv",
        "path",
        "url",
        "unique-names-generator",
        "handlebars",
        "@ai-sdk/*",
        "langchain/*",
        "ai",
        "buffer",
        "openai",
        "js-tiktoken",
        "together-ai",
        "zod",
        "@fal-ai/client",
        "fs",
        "fs/promises",
        "uuid",
        "glob",
        "pino",
        "pino-pretty",
        "js-sha1",
        "stream"
    ],
});
