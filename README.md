# PAUSE

**A Vestaboard-inspired ambient attention display.** It uses real Mac activity to notice when a social session has run past your own limit, or when extended creative work could use a break — without putting another dashboard in your face.

**Status:** V2 prototype. Runs locally with ActivityWatch. Static deployments continue to work in clearly labeled demo mode. No AI provider is connected yet; current nudges use understandable thresholds and tone templates.

## Run with real screen time on your Mac

### 1. Install ActivityWatch

Download and start [ActivityWatch](https://activitywatch.net/downloads/). Open [http://localhost:5600](http://localhost:5600) to confirm that its dashboard is recording app usage.

Grant ActivityWatch's window watcher Accessibility permission if macOS requests it. PAUSE itself does **not** need Accessibility, Full Disk Access, or Screen Recording permission.

For individual sites such as Instagram and YouTube, also install the official [ActivityWatch Web Watcher for Chrome / Chromium](https://chromewebstore.google.com/detail/activitywatch-web-watcher/nglaklhklhcoonedhgnpgddginnjdadi) (or [Firefox watcher](https://addons.mozilla.org/en-US/firefox/addon/activitywatch-web-watcher/)). Browser-level activity alone can't distinguish Instagram from other open sites. The PAUSE connector currently relies on the browser watcher for per-site activity; Safari is not supported for per-site PAUSE nudges.

### 2. Start PAUSE locally

On your Mac, open Terminal:

```bash
git clone https://github.com/mail2tarunv-cpu/pause.git
cd pause
python3 bridge.py
```

If you already cloned the repo, use `git pull` from its folder instead of cloning again.

Open **http://127.0.0.1:8765**. Leave Terminal and ActivityWatch running while using the board. Choose **Attention → Mac activity**.

There are no Python packages to install. Python 3.9+ is required.

### 3. Set your nudges

In **Attention**:
- Configure continuous-use limits for **Social**, **Creative / work**, and **Entertainment**.
- Pick a message tone (gentle, playful, direct) and cooldown (subtle, balanced, assertive).
- Change categories for detected apps and websites, or give them individual minute limits.
- Use **Take a break**, **Keep going**, or **Not helpful** when a nudge appears. These responses affect cooldowns; repeated unhelpful responses prompt you to consider a different limit.

An app classified **Other** or **Ignore** does not trigger nudges. All limits and feedback are stored in your browser's localStorage, so they'll be different across browsers/devices. Nudges work while the board page remains open — this is not a system-wide background notification service.

## Test without ActivityWatch

Open `index.html` directly or deploy it on Vercel as a static site (no build step). Choose **Attention → Demo mode**, pick Instagram, Figma, or YouTube, and press **+5 min** until the category threshold is reached. Use **Preview a nudge** to test the tone immediately.

**Important:** Demo data is fake and explicitly labeled. A static Vercel deployment does **not** connect to your Mac ActivityWatch service: open the local board URL above for real tracking. The bridge is intentionally accessible only on loopback.

## How tracking works

```
ActivityWatch (local Mac app and AFK watchers)
              +
ActivityWatch browser extension (optional website activity)
              |
       bridge.py (127.0.0.1:8765)
              |
    GET /pause-api/status every 15 seconds
              |
     PAUSE browser nudge rules
              |
      Vestaboard-style display
```

The bridge uses ActivityWatch's [documented REST API](https://docs.activitywatch.net/en/latest/api/rest.html). It reads daily local events, excludes AFK periods, and gives website activity precedence over the browser application so overlapping events are not counted twice. It returns **application names and website hostnames only** — not raw URLs, page titles, search terms, or document titles. It doesn't upload your screen activity.

Current session calculations are approximate because ActivityWatch updates via periodic watcher heartbeats and has its own idle detection timeout. PAUSE reports **Mac activity**, not the iPhone Screen Time total.

## Project files

- `index.html` — V1 6 × 22 split-flap board and message composer
- `v2.css`, `v2.js` — attention controls, live/demo modes, nudge states and feedback
- `bridge.py` — standard-library ActivityWatch companion/server
- `tests/test_bridge.py` — aggregation, idle time, browser precedence and privacy tests

## Development checks

```bash
python3 -m unittest discover -s tests -v
python3 -m py_compile bridge.py
node --check v2.js
```

## Explicitly not in V2

- No iOS/iPhone Screen Time ingestion
- No AI-generated nudges or model-driven timing
- No macOS global notification daemon
- No automatic blocking of websites or applications
- No cloud collection or tracking across devices

This is an independent concept prototype, not affiliated with or endorsed by Vestaboard.
