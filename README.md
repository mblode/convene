# Convene

macOS meeting transcription app — Granola-style. Captures both sides of a video call (mic + system audio), transcribes live with OpenAI Realtime, takes notes alongside, and produces an AI summary on stop.

BYO OpenAI key. Local-first storage. Multi-calendar via EventKit. Auto-detects Zoom / Teams / Webex / Meet / BlueJeans / Slack on launch.

## Status

All seven phases of the [implementation plan](../../.claude/plans/i-want-to-make-compressed-kahan.md) are scaffolded:

- **Phase 1** — Audio capture (mic via VoiceProcessingIO + AEC, system via ScreenCaptureKit), 24 kHz PCM mono
- **Phase 2** — Two-stream live transcription with server-VAD continuous mode, merged segment list
- **Phase 3** — Notes editor + Markdown / JSON persistence to a security-scoped output folder
- **Phase 4** — AI summary via OpenAI Chat Completions (`response_format: json_schema`)
- **Phase 5** — EventKit-backed today's-events list (iCloud + Gmail + Fastmail + any other CalDAV/Exchange) with one-click "start recording from this event"
- **Phase 6** — App-launch detection (Zoom / Teams / Webex / Meet / BlueJeans / Slack) with notification banners
- **Phase 7** — Makefile, GitHub Actions release workflow, Homebrew cask template

The Xcode project (`Convene.xcodeproj`) is generated from `project.yml` and committed for convenience.

## Repo layout

```
Convene/
├── Audio/                  Mic + system audio capture, WAV writer
├── Transcription/          OpenAI Realtime API client (transcription mode)
├── Calendar/               EventKit wrapper (multi-account)
├── Detection/              NSWorkspace meeting detector + UN delegate
├── Storage/                Markdown / JSON persistence with security-scoped bookmarks
├── Summary/                Chat Completions structured-output summary service
├── Models/                 MeetingStore, Meeting, TranscriptSegment
├── UI/                     SwiftUI views: meeting window, menu, settings
├── Util/                   Logger
├── Hotkeys/                KeyboardShortcuts setup
├── Keychain/               OpenAI API key storage
├── Info.plist
└── Convene.entitlements
.github/workflows/release.yml   Build → notarize → DMG → GitHub Release
homebrew/convene.rb             Cask template (publish to mblode/homebrew-tap)
Makefile                        build / install / archive / dmg / notarize
```

## Bootstrap (one-time)

The Xcode project is generated from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen           # one-time
xcodegen generate                # refreshes Convene.xcodeproj
open Convene.xcodeproj           # or `make install` to build + relaunch
```

Re-run `xcodegen generate` whenever you add a Swift file or change `project.yml`. SPM resolves the `KeyboardShortcuts` dependency automatically on first build.

## Required permissions (first run)

Convene will prompt for these:

- **Microphone** — to capture your side
- **Screen Recording** — required by ScreenCaptureKit even for audio-only capture; no video is recorded
- **Calendar** — to attach meetings to events from all configured macOS calendars
- **Notifications** — for the "meeting detected" banner

## Build

```bash
make build          # Release build
make install        # Debug build → /Applications/Convene.app → relaunch
make dmg            # Build + sign + create DMG
make notarize       # Build + DMG + notarize (requires APPLE_TEAM_ID, NOTARIZE_APPLE_ID, NOTARIZE_PASSWORD)
make clean          # Remove /tmp/convene-build
```

## Reuse provenance

Bits of code adapted from sibling projects:

- `Transcription/RealtimeTranscriptionClient.swift` — verbatim from `~/Code/mblode/commandment/`. Used for one-shot commit/transcribe; not currently wired (kept available for future use).
- `Transcription/LiveTranscriptionStream.swift` — new for Convene; continuous server-VAD transcription.
- `Keychain/KeychainManager.swift`, `Util/Logger.swift`, `Hotkeys/HotkeyManager.swift` — adapted from `~/Code/mblode/commandment/` (service id / log filename swapped).
- `Audio/MicCapture.swift` — slimmed-down adaptation of `~/Code/mblode/rubber-duck/apps/macos/AudioManager.swift`. Kept the 24 kHz PCM mono pipeline + VoiceProcessingIO hardware AEC + noise gate. Dropped the playback-coupled software AEC and startup planner (not relevant for meeting transcription).
- Everything in `Audio/SystemAudioCapture.swift`, `Audio/AudioCaptureCoordinator.swift`, `Audio/WAVFileWriter.swift`, `Calendar/`, `Detection/`, `Storage/`, `Summary/`, and most of `Models/` and `UI/` — new.

## Release flow

Tag-driven via GitHub Actions:

```bash
git tag v0.1.0 && git push origin main --tags
```

The `release.yml` workflow builds → signs (Developer ID) → notarizes → creates a GitHub Release with the DMG attached → signs and publishes the Sparkle appcast → updates the Homebrew tap.

Required secrets: `DEVELOPER_ID_CERT_P12`, `DEVELOPER_ID_CERT_PASSWORD`, `APPLE_TEAM_ID`, `NOTARIZE_APPLE_ID`, `NOTARIZE_PASSWORD`, `SPARKLE_PRIVATE_ED_KEY`, and `HOMEBREW_TAP_TOKEN`.

Sparkle checks `https://raw.githubusercontent.com/mblode/convene/main/appcast.xml`, and the generated Homebrew cask is published to `mblode/homebrew-tap`.
