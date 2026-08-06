<div align="center">

# [Convene](https://blode.co/convene)

**Records your meetings on macOS and iPhone, then writes the notes into a folder you own**

Live transcription and AI summaries on your own AssemblyAI and Anthropic keys, with no server in between.

</div>

## Install

```bash
brew install --cask mblode/tap/convene
```

Or [download the latest release](https://github.com/mblode/convene/releases/latest). Requires macOS 15 Sequoia or later. First launch asks for Microphone, Screen Recording (audio only, no video), Calendar, and Notifications, then the app updates itself.

## Quickstart

Open Settings and add an [AssemblyAI](https://www.assemblyai.com/dashboard/api-keys) key for transcription, plus an [Anthropic](https://console.anthropic.com/settings/keys) or [OpenAI](https://platform.openai.com/api-keys) key for summaries. Both go into your Keychain. Claude writes the better summaries.

Press `⌥⇧R` from anywhere, hold the meeting, then press it again. The note is on disk before you close the window.

## What it does

- **Both sides of a call:** your microphone and the other side's audio, transcribed live and split by speaker.
- **Calendar in the menu bar:** today's events are one click from joining and recording.
- **Meeting detection:** Convene notices Zoom, Teams, Webex, Meet, and BlueJeans opening, and offers to record.
- **Key moments:** `⌥⇧K` flags the thing that just got said, and it lands in the note as its own section.
- **Your keys, your files:** keys sit in your Keychain and notes sit in your folder. The only things that leave your Mac are the audio you send to transcribe and the transcript you send for a summary.

## Your notes

Pick a save folder and every meeting lands there as `2026-07-22 103128 - Standup - a1b2c3d4.md`: YAML frontmatter, the summary, your notes, key moments, then the timestamped transcript. Point it at an Obsidian vault and meetings show up there on their own.

## On iPhone

For the meetings that are in a room rather than on a call. Put the phone on the table and hit record.

- **One microphone, not two:** iOS will not let an app capture another app's audio, so AssemblyAI's diarization does the splitting into Speaker A, Speaker B, and so on.
- **Everything else is the Mac app:** live transcript, key moments, your own notes, an AI summary, and a Markdown file at the end.
- **Survives interruptions:** it keeps recording through a locked screen and picks itself back up after a phone call.
- **Your vault:** tap **Choose your vault** in Settings and browse to an Obsidian vault, on the device or in iCloud Drive. Leave it alone and notes stay under **On My iPhone** in the Files app.

Needs iOS 17 or later. [Join the TestFlight beta](https://testflight.apple.com/join/ZphcgfD7) while it goes through App Store review.

## License

MIT

---

Crafted by [<img src="https://blode.co/avatar-circle.png" width="20" align="top" />](https://blode.co) [Matthew Blode](https://blode.co)
