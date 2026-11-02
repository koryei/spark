# Spark

Private tool for one user: a macOS menu bar app that wakes a home server (Wake-on-LAN) and suspends it (`ssh … sudo -n systemctl suspend`), plus a one-screen landing page hosted on Vercel.

## Layout
- `app/`: Swift/AppKit menu bar app. `build.sh` compiles with `swiftc` into `app/build/Spark.app` (accessory app, no Dock icon). Config at `~/.config/spark/config.json`.
- `web/`: single static `index.html`. Design direction "The sentence is the layout" (design-taste-frontend): Sentient serif, sky/navy palette, orange accent on the one action only. The inline switch toggles the whole page between awake and asleep.

## Decisions
- No website backend: the app talks to the server directly (UDP broadcast, system `ssh`).
- Page passes `inspect.mjs` only with `--allow few-pictures,still-page,no-footage`: those rules target multi-section pages, and this one is a single viewport by request.
- `web/Spark.zip` (the download) is git-ignored; build it locally.

## Status
App builds and launches; magic-packet bytes verified on loopback. Not yet tested against the real server. Landing page done at 1440/768/390.
