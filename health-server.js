const express = require("express");
const app = express();
const port = process.env.PORT || 8080;

console.log("Starting health check server on port:", port);

// Health check endpoint
app.get("/health", (req, res) => {
  console.log("Health check request received at " + new Date().toISOString());
  res.status(200).json({ status: "ok" });
});

// Root endpoint
app.get("/", (req, res) => {
  console.log("Root request received");
  res.status(200).send("ElizaOS is running");
});

// Catch-all for any other requests
app.get("*", (req, res) => {
  console.log("Request received:", req.url);
  res.status(200).send("Service is running");
});

// Start the server
app.listen(port, "0.0.0.0", () => {
  console.log(`Health check server running on port ${port} at ${new Date().toISOString()}`);
});

// Export the app for potential testing
module.exports = app; 