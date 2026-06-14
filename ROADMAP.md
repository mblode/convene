# Convene — Roadmap

> Future state. See **[FEATURES.md](FEATURES.md)** for what ships today.

Ordered by leverage. Each item notes *why now* and what it builds on.

## P0 — Key Moments (the differentiator) ⭐

Timestamped, human-marked flags you drop **live** with a hotkey (`⌘K`-style),
landing inline in the transcript at the exact second — plus a "Key Moments"
index at the top that links to the spot.

- *Why*: it's the one feature the landing page sells, HN praised, and the code
  lacks. It encodes **human judgment** ("this matters"), which no amount of model
  inference replaces — and it's what makes Convene an *annotation layer* rather
  than passive transcription.
- *Builds on*: add `keyMoments: [{ offset, text }]` to `Meeting`; reuse the
  existing `MM:SS` section anchors and `citation()` wikilink logic in
  `MarkdownRenderer`; add a hotkey + lightweight always-on-top capture field.
- *Small, high-impact.*

## P1 — Live Recap (`⌘?`), pull not push

Glanceable last-2-minutes view, interleaved with your flagged moments, on demand.

- *Why*: solves the "I zoned out" moment and is genuinely novel on-device.
- *Guardrail*: keep it **pull** (you summon it), never proactive suggestion —
  that would contradict "out of the way until you need it" and wander into a
  different product. Latency target: feels live (sub-few-seconds) when summoned.
- *Builds on*: `meeting.transcript` is already live in memory.

## P2 — On-device / offline path (close the privacy gap)

Local transcription (WhisperKit / Apple Speech) and **local summarization**
(Apple Foundation Models / on-device MLX) as a first-class mode, so the
"never leaves your Mac" promise is literally true and works with the network off.

- *Why*: the only moment the privacy story breaks today is the cloud transcribe +
  "paste into ChatGPT/Claude" handoff. Owning the on-device path is the claim no
  cloud competitor (Granola, Otter) can make.
- *Shape*: keep AssemblyAI/OpenAI/Anthropic as the high-accuracy option; add a
  local engine toggle in **Models** settings. For very long calls, anchor
  progressive compression around the Key-Moment timestamps (verbatim at flags,
  summarized between).

## P3 — Floating pill + notch surface (Amie-inspired)

A summonable HUD that lives over any app (Zoom/Meet/Teams), showing record state,
timer, `⌘K` entry, and `⌘?` recap. On notched MacBooks it docks into the **notch**
(Dynamic-Island-style, expands on interaction); elsewhere it's a floating pill.

- *Why*: the pill is the product's signature surface; the menu bar stays the
  passive "home / library", the pill is the active session HUD.
- *Shape*: one state machine, two presentations (pill = baseline, notch =
  enhancement when hardware allows).

## P4 — Speaker identity that persists

Rename a speaker once; remember them across meetings (on-device voiceprint,
opt-in). Replaces "Speaker 1 / Speaker 2".

- *Builds on*: existing diarization + `selfName`/`othersName`.

## P5 — Library & search

In-app searchable history across all transcripts and key moments (currently it's
Finder files + "open latest"). The retention hook once a corpus exists.

## P6 — Smaller wins

- **Browser meeting detection** (Meet/Zoom in a tab) via accessibility window-title polling — fills a known gap.
- **In-app notes editing** on macOS (today notes are effectively write-via-model only).
- **Templates** per meeting type (1:1, standup, customer call) shaping summary output.
- Fix cosmetics surfaced in mockups (e.g. "0 KB" sessions reading as bugs).

## Positioning thread (applies throughout)

Lead with **"real-time annotation, not post-hoc cleanup"**; offline/private is the
proof point underneath. Keep the human as the one who decides what matters
(`⌘K`); let AI organize, never interrupt.
