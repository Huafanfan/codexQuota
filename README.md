# Codex Quota Menu Bar

A native macOS menu bar app that reads local Codex session data from `~/.codex/sessions` and shows the remaining quota for the rolling 5-hour and 7-day windows.

## Features

- Native menu bar UI built with AppKit
- Two-line status display for `5H` and `7D`
- Remaining quota percentage plus reset time
- Lightweight color warning for lower remaining quota
- Launch-at-login toggle from the menu
- One-command build script
- Automatic install to `/Applications/CodexQuota.app` after each build

## Data source

The app scans local `rollout-*.jsonl` files under `~/.codex/sessions` and picks the latest real `event_msg -> token_count` event. It reads:

- `rate_limits.primary` for the 5-hour window
- `rate_limits.secondary` for the 7-day window

No network requests are made. Everything is read from the local Codex state on your Mac.

## Build

```bash
./scripts/build_app.sh
```

That command will:

1. Compile the menu bar app
2. Generate app icon assets
3. Build `./dist/CodexQuota.app`
4. Install or overwrite `/Applications/CodexQuota.app`

## Run

```bash
open /Applications/CodexQuota.app
```

## Project layout

- `Sources/main.m` — AppKit menu bar app
- `scripts/build_app.sh` — build and install script
- `scripts/render_icon.m` — icon renderer used by the build script

## Requirements

- macOS 13+
- Apple Command Line Tools
- A local Codex installation that has already produced at least one `token_count` event
