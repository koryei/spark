# Spark

Private tool for one user: a macOS menu bar app that wakes a home server (Wake-on-LAN) and suspends it (`ssh … sudo -n systemctl suspend`), plus a one-screen landing page hosted on Vercel.

## Layout
- `app/`: Swift/AppKit menu bar app. `build.sh` compiles with `swiftc` into `app/build/Spark.app` (accessory app, no Dock icon). Config at `~/.config/spark/config.json`, edited through the native Settings window (`SettingsWindow.swift`: fields, Copy public key, Test connection).
- `web/`: single static `index.html`. Design direction "The sentence is the layout" (design-taste-frontend): Sentient serif, sky/navy palette, orange accent on the one action only. The inline switch toggles the whole page between awake and asleep.

## Decisions
- No website backend: the app talks to the server directly (UDP broadcast, system `ssh`).
- Page passes `inspect.mjs` only with `--allow few-pictures,still-page,no-footage`: those rules target multi-section pages, and this one is a single viewport by request.
- The download button links to the repo's GitHub Releases page (owner's change); `web/Spark.zip` is git-ignored and no longer needed.
- Setup guide lives in `docs/setup.md` (a GitHub wiki can't be created by API, so docs are in the repo). The in-app hints refer to its step 3 (key) and step 4 (sudo rule): keep those numbers stable.
- Verification without a screen: `screencapture` is blocked, so the Settings window was checked by rendering its content view to PNG from a small throwaway harness.

## Status
App builds and launches; works end to end against the real server (wake and sleep confirmed by the owner). Settings window and connection test added and checked against the real server, including failure cases. Landing page done at 1440/768/390.
