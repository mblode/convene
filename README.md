<p align="center">
  <img src="AppIcon-iOS-Default-1024x1024@1x.png" width="128" alt="Convene app icon">
</p>

<h1 align="center">Convene</h1>

<p align="center">
  An open-source Granola clone for macOS and iPhone. Records your meetings, transcribes them live, and writes the notes into a folder you own.
</p>

## What it does

- Records both sides of a call: your mic and the other side's audio
- Transcribes live while the meeting runs, split by speaker
- Saves a Markdown note when you stop, with an AI summary and the full transcript
- Puts today's calendar in the menu bar. Click an event to join it and start recording
- Notices Zoom, Teams, Webex, Meet, and BlueJeans opening, and offers to record
- `⌥⇧R` records from anywhere, `⌥⇧K` flags a key moment mid-meeting
- Keys stay in your Keychain, notes stay in your folder. There's no Convene server

## On iPhone

The iPhone app is for the meetings that aren't on a call. Put the phone on the table, hit record, and it transcribes the room — iOS won't let an app capture another app's audio, so instead of the Mac's two streams there's one microphone and AssemblyAI's diarization separating who said what into Speaker A, Speaker B, and so on.

Everything else is the Mac app: live transcript, `Key moment` to flag something as it happens, notes while you talk, an AI summary when you stop, and a markdown file at the end. It keeps recording when the screen locks, and picks itself back up after a phone call interrupts it.

Notes go to the same place they do on the Mac: your own folder. In Settings, tap **Choose your vault** and browse to your Obsidian vault — Obsidian and iCloud Drive both show up in the file browser — and meetings land there as markdown, syncing to the same vault on your Mac. Leave it alone and they stay in Convene's folder under **On My iPhone** in the Files app.

Needs iOS 17 or later. There's no App Store build yet — clone the repo and run `make ios-run`, or open `Convene.xcodeproj` and run the `ConveneMobile` scheme on your phone.

## Install

The Mac app needs macOS 15 (Sequoia) or later.

<strong><a href="https://github.com/mblode/convene/releases/latest">Download the latest release</a></strong>, or:

```bash
brew tap mblode/tap
brew install --cask convene
```

First launch asks for Microphone, Screen Recording (audio only, no video), Calendar, and Notifications. Convene updates itself from there.

## Keys

Add these in Settings. They're stored in your Keychain.

- **[AssemblyAI](https://www.assemblyai.com/dashboard/api-keys)** for transcription. Required.
- **[Anthropic](https://console.anthropic.com/settings/keys) or [OpenAI](https://platform.openai.com/api-keys)** for summaries. Optional, and Claude writes the better ones.

## Your notes

Pick a save folder and every meeting lands there as `2026-07-22 103128 - Standup - a1b2c3d4.md`: YAML frontmatter, the summary, your notes, key moments, then the timestamped transcript. Point it at an Obsidian vault and meetings show up there on their own.

## License

MIT

---

Crafted by [<img src="https://blode.co/avatar-circle.png" width="20" align="top" />](https://blode.co) [Matthew Blode](https://blode.co)
