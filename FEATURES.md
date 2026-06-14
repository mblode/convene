# Convene — Features

> Status: as of v0.1.6 · Last updated 2026-06-14
> Positioning: **a real-time annotation layer for meetings, not a post-call cleanup pass.** Your transcript, your folder, your keys.
> See **[ROADMAP.md](ROADMAP.md)** for what's planned next.

## Current state (shipping today)

### Capture
- **Dual-stream audio**: microphone (16 kHz mono, hardware AEC via VoiceProcessingIO when available) + system/remote audio (ScreenCaptureKit). Streams labelled `.you` (mic) and `.others` (system).
- **Bleed control**: `CrossStreamGate` drops mic chunks that are just remote-speaker playback (on by default); noise gating on the mic.
- **Optional raw WAV** export per stream for debugging (`-you.wav`, `-others.wav`).

### Transcription
- **Provider**: AssemblyAI Universal-3 Pro, **real-time streaming** over WebSocket (cloud).
- **Speakers**: `.you` vs `.others`, plus AssemblyAI diarization labels (A/B/C…) on the remote stream; optional named speakers for 1:1s.
- **Key-terms biasing**: builds a term list from attendee names + meeting-title words to improve accuracy (`KeytermsBuilder`).
- **Crash safety**: write-ahead log (`TranscriptWALService`, JSONL) recovers segments after a crash with a `[Recovered]` marker.

### Summary (AI)
- **Providers**: OpenAI or Anthropic (BYO key); auto-runs after recording stops (toggle).
- **Structured output**: overview/TL;DR, topics, key points, **decisions**, **action items** (checklist), open questions, follow-ups, plus thematic "details" sections with `MM:SS` citations that link back to transcript headers.
- Source-grounded prompt (no invented facts); transcript deduped before summarizing.

### Key moments (live annotation) ⭐
- **Timestamped flags** dropped live with a hotkey (`⌥⇧K`): mark "this matters" the instant it happens, anchored to the exact meeting second.
- **Optional annotation**: the flag lands immediately; a lightweight always-on-top capture field lets you add a note (or skip it — a bare flag still counts).
- **Renders inline + indexed**: a "## Key Moments" index near the top links to the spot, and each flag appears as an inline `⭐` marker in the transcript. Survives crashes via the WAL.

### Live recap (`⌥⇧/`)
- **Pull, never push**: summon a glanceable view of the last ~2 minutes, interleaved with your flagged moments — on-device and instant.
- **Optional AI catch-up**: when a Claude key is set, a 2–3 sentence "what's being discussed right now" recap fills in on demand; the raw timeline shows regardless.

### Floating pill (HUD over any app)
- **Signature session surface**: a non-activating floating pill appears over Zoom/Meet/Teams while recording, showing the record dot, live timer, and `⌥⇧K` / `⌥⇧/` affordances.
- **Notch-aware**: docks snug under the notch (Dynamic-Island-style, flat top edge) on notched MacBooks; a free-floating pill below the menu bar elsewhere. One state machine, two presentations — expands into the capture field or recap on interaction.

### Notes
- Free-text `notes` field per meeting, rendered as one section in the markdown. **Untimed**, and **no editing UI in the macOS menu bar** (mobile has a field).

### Meeting awareness
- **App detection**: Zoom, Teams, Webex, Meet (desktop app), BlueJeans, Slack → notification offering to record; optional auto-stop when the meeting app quits.
- **Calendar** (EventKit; iCloud, Gmail, Fastmail, CalDAV, Exchange): upcoming-event pill with countdown, one-click **join & record**, meeting-link detection (Meet/Zoom/Teams/Webex/Jitsi/Whereby), configurable browser, "only events with meetings" filter, auto-record-on-join.

### Surface & control
- **Menu-bar app** (NSPopover): record button + live timer, imminent-event pill, schedule grouped by day, per-event actions, open-latest-transcript.
- **Global hotkeys**: toggle recording (`⌥⇧R`), flag key moment (`⌥⇧K`), live recap (`⌥⇧/`), open settings (`⌥⇧,`) — all rebindable.
- **Settings**: General, Models (keys + summary model), Calendar, Capture, Hotkeys, Permissions, About.

### Output & storage
- **Markdown + JSON** per meeting, to a user-picked folder (security-scoped bookmark; Obsidian-vault auto-detect), fallback to App Support.
- Rich YAML frontmatter; transcript as `Speaker [MM:SS]: text`; Obsidian-style citation links from summary to transcript.

### Platform & ops
- macOS 15+, Apple silicon. **Sparkle** auto-updates (appcast). Keys in Keychain.
- **iOS companion** (ConveneMobile): mic-only record, live transcript, Claude summary, local/iCloud save.
- **Web**: open-source marketing site (Next.js) with GitHub download.

## Honest gaps (marketed or implied, not yet built)

These are referenced in the landing copy or implied by positioning, but are **not** in the code today. See [ROADMAP.md](ROADMAP.md) for how each is addressed.

- ✅ Timestamped **key moments** (`⌥⇧K` inline flags) — shipped (see Key moments above).
- ✅ Live **recap** (`⌥⇧/`) during the call — shipped (on-device timeline + optional AI catch-up).
- ✅ Floating **pill** + **notch** UI — shipped (see Floating pill above).
- ❌ **On-device / offline** transcription & summary — all cloud today (AssemblyAI + OpenAI/Anthropic).
- ❌ **Browser-based** meeting detection (Meet/Zoom in a tab).
