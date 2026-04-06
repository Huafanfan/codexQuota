const fs = require("node:fs");
const path = require("node:path");

const rootDir = path.resolve(__dirname, "..");
const appDir = path.join(rootDir, "release", "CodexQuota-darwin-arm64", "CodexQuota.app");
const installDir = "/Applications/CodexQuota.app";

if (!fs.existsSync(appDir)) {
  console.error(`Missing app bundle: ${appDir}`);
  process.exit(1);
}

console.log(`Electron app bundle ready at ${appDir}`);
console.log(`Install target: ${installDir}`);
