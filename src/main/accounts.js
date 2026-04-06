const fs = require("node:fs/promises");
const path = require("node:path");

class AccountStore {
  constructor(userDataPath) {
    this.filePath = path.join(userDataPath, "accounts.json");
  }

  async list() {
    try {
      const raw = await fs.readFile(this.filePath, "utf8");
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed.accounts) ? parsed.accounts : [];
    } catch {
      return [];
    }
  }

  async save(accounts) {
    await fs.writeFile(this.filePath, JSON.stringify({ accounts }, null, 2));
  }

  async add(account) {
    const accounts = await this.list();
    accounts.push(account);
    await this.save(accounts);
    return account;
  }
}

function createAccountRecord(name) {
  const id = `account-${Date.now()}`;
  return {
    id,
    name: name || `Account ${new Date().toLocaleString()}`,
    partition: `persist:${id}`,
    createdAt: new Date().toISOString(),
    source: "web",
    status: "authorized"
  };
}

module.exports = {
  AccountStore,
  createAccountRecord
};
