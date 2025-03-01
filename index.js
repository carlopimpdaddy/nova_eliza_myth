// Railway entry point for the agent
console.log("Railway agent entry point starting...");

// IMPORTANT: Only start one health check server - let the main app run separately
try {
  console.log("Starting health check server from agent entry point");
  // Start primary health check server - this is what Railway will probe
  if (require("fs").existsSync("/app/health-server.js")) {
    console.log("Found health server, starting it");
    require("/app/health-server.js");
  } else {
    // Create a simple health check server
    console.log("Health server not found, creating a simple one");
    const http = require("http");
    const port = process.env.PORT || 8080;
    const server = http.createServer((req, res) => {
      console.log("Received request:", req.url);
      if (req.url === "/health") {
        res.statusCode = 200;
        res.setHeader("Content-Type", "application/json");
        res.end(JSON.stringify({ status: "ok" }));
      } else {
        res.statusCode = 200;
        res.setHeader("Content-Type", "text/plain");
        res.end("Service is running");
      }
    });
    server.listen(port, "0.0.0.0", () => {
      console.log(`Server running at http://0.0.0.0:${port}/`);
    });
  }

  // Run our start script to launch the ElizaOS application
  if (require("fs").existsSync("/app/start.sh")) {
    console.log("Found start.sh, executing it");
    // Check file permissions
    const fs = require("fs");
    try {
      // Try to set execute permissions
      fs.chmodSync("/app/start.sh", 0o755);
      console.log("Set executable permissions on /app/start.sh");
    } catch (permError) {
      console.error("Failed to set permissions:", permError);
    }
    // Use spawn instead of execSync to avoid blocking the health check server
    require("child_process").spawn("/app/start.sh", [], { stdio: "inherit", shell: true });
  }
} catch (error) {
  console.error("Error in agent entry point:", error);
}

module.exports = { start: () => console.log("Agent module loaded") }; 