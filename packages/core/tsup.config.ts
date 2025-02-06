import { defineConfig } from "tsup";

export default defineConfig({
    entry: ["src/index.ts"],
    format: ["esm"],
    dts: true,
    sourcemap: true,
    clean: true,
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
        "stream",
        "node:*"
    ],
    noExternal: []
});
