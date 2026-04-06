# CodexQuota

Electron-based macOS tray app for Codex quota tracking, designed to keep the current local-session parser and make room for future multi-account ChatGPT web authorization.

## Why Electron

This project moved from a native AppKit-only prototype to Electron because future quota tracking via the ChatGPT usage page will need:

- independent login sessions per account
- durable cookie isolation
- multiple authorized accounts on the same machine

Electron gives that through per-account persistent `session` partitions.

## Current features

- Tray app with compact `5H` / `7D` quota readout
- Main dashboard window for quota details
- Local quota parsing from `~/.codex/sessions`
- Launch-at-login toggle from the tray menu
- Web-account authorization skeleton with isolated Electron sessions
- Automatic install to `/Applications/CodexQuota.app`

## Local quota source

The app scans local `rollout-*.jsonl` files under `~/.codex/sessions` and picks the latest valid `event_msg -> token_count` event.

It reads:

- `rate_limits.primary` for the rolling 5-hour window
- `rate_limits.secondary` for the rolling 7-day window

## Web account direction

The Electron migration also adds the architecture for future usage-page integrations:

- each web account gets its own persistent Electron partition
- login happens in a dedicated browser window
- account metadata is stored under Electron `userData`

The current code sets up authorization storage and session isolation. It does not yet parse the remote usage page into live quota data.

## Build and install

```bash
./scripts/build_app.sh
```

That script will:

1. install npm dependencies when missing
2. package the Electron app for macOS arm64
3. copy the built app to `/Applications/CodexQuota.app`

## Run in development

```bash
npm install
npm run dev
```

## Run installed app

```bash
open /Applications/CodexQuota.app
```

## Project layout

- `src/main/` — Electron main process, tray integration, quota parser, account store
- `src/renderer/` — dashboard UI
- `scripts/build_app.sh` — package and install script

## Requirements

- macOS
- Node.js and npm
- local Codex usage data under `~/.codex/sessions`
