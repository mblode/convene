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

### Notes
- Free-text `notes` field per meeting, rendered as one section in the markdown. **Untimed**, and **no editing UI in the macOS menu bar** (mobile has a field).

### Meeting awareness
- **App detection**: Zoom, Teams, Webex, Meet (desktop app), BlueJeans, Slack → notification offering to record; optional auto-stop when the meeting app quits.
- **Calendar** (EventKit; iCloud, Gmail, Fastmail, CalDAV, Exchange): upcoming-event pill with countdown, one-click **join & record**, meeting-link detection (Meet/Zoom/Teams/Webex/Jitsi/Whereby), configurable browser, "only events with meetings" filter, auto-record-on-join.

### Surface & control
- **Menu-bar app** (NSPopover): record button + live timer, imminent-event pill, schedule grouped by day, per-event actions, open-latest-transcript.
- **Global hotkeys**: toggle recording (`⌥⇧R`), open settings (`⌥⇧,`) — both rebindable.
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

- ❌ Timestamped **key moments** (`⌘K` inline flags) — only an untimed notes blob exists.
- ❌ Live **recap** (`⌘?`) during the call.
- ❌ Floating **pill / overlay**, and ❌ **notch** UI — menu-bar popover only.
- ❌ **On-device / offline** transcription & summary — all cloud today (AssemblyAI + OpenAI/Anthropic).
- ❌ **Browser-based** meeting detection (Meet/Zoom in a tab).
