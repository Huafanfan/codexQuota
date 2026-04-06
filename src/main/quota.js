const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

function sessionsRoot() {
  return path.join(os.homedir(), ".codex", "sessions");
}

async function walkRollouts(root) {
  const output = [];

  async function visit(dir) {
    let entries = [];
    try {
      entries = await fs.readdir(dir, { withFileTypes: true });
    } catch {
      return;
    }

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        await visit(fullPath);
        continue;
      }

      if (entry.isFile() && entry.name.startsWith("rollout-") && entry.name.endsWith(".jsonl")) {
        output.push(fullPath);
      }
    }
  }

  await visit(root);
  return output;
}

function normalizeRateWindow(window) {
  if (!window || typeof window !== "object") return null;
  return {
    usedPercent: Number(window.used_percent ?? 0),
    windowMinutes: Number(window.window_minutes ?? 0),
    resetsAt: Number(window.resets_at ?? 0)
  };
}

function normalizeSnapshot(filePath, line) {
  if (!line || line.type !== "event_msg" || !line.payload || line.payload.type !== "token_count") {
    return null;
  }

  const rateLimits = line.payload.rate_limits;
  if (!rateLimits) return null;

  const primary = normalizeRateWindow(rateLimits.primary);
  const secondary = normalizeRateWindow(rateLimits.secondary);
  if (!primary || !secondary) return null;

  const eventAt = new Date(line.timestamp);
  if (Number.isNaN(eventAt.getTime())) return null;

  return {
    source: "local",
    sourcePath: filePath,
    eventAt: eventAt.toISOString(),
    planType: rateLimits.plan_type ?? "unknown",
    primary,
    secondary
  };
}

async function parseRollout(filePath) {
  let text = "";
  try {
    text = await fs.readFile(filePath, "utf8");
  } catch {
    return null;
  }

  let latest = null;
  for (const rawLine of text.split(/\r?\n/)) {
    if (!rawLine.includes('"type":"token_count"') || !rawLine.includes('"type":"event_msg"')) {
      continue;
    }

    let parsed = null;
    try {
      parsed = JSON.parse(rawLine);
    } catch {
      continue;
    }

    const snapshot = normalizeSnapshot(filePath, parsed);
    if (!snapshot) continue;

    if (!latest || snapshot.eventAt > latest.eventAt) {
      latest = snapshot;
    }
  }

  return latest;
}

async function readLatestLocalQuota() {
  const root = sessionsRoot();
  const rolloutFiles = await walkRollouts(root);
  if (rolloutFiles.length === 0) {
    return null;
  }

  let best = null;
  for (const filePath of rolloutFiles) {
    const snapshot = await parseRollout(filePath);
    if (!snapshot) continue;
    if (!best || snapshot.eventAt > best.eventAt) {
      best = snapshot;
    }
  }

  return best;
}

function remainingPercent(window) {
  return Math.max(0, 100 - Number(window?.usedPercent ?? 0));
}

function formatPercent(value) {
  return `${Math.round(value)}%`;
}

function formatShortReset(window) {
  const date = new Date(Number(window?.resetsAt ?? 0) * 1000);
  if (Number.isNaN(date.getTime())) return "--";

  if ((window?.windowMinutes ?? 0) <= 300) {
    return new Intl.DateTimeFormat(undefined, {
      hour: "numeric",
      minute: "2-digit"
    }).format(date);
  }

  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric"
  }).format(date);
}

function formatLongDate(isoString) {
  const date = new Date(isoString);
  if (Number.isNaN(date.getTime())) return "--";

  return new Intl.DateTimeFormat(undefined, {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit"
  }).format(date);
}

module.exports = {
  readLatestLocalQuota,
  remainingPercent,
  formatPercent,
  formatShortReset,
  formatLongDate
};
