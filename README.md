<p align="center">
  <img src="AppIcon-iOS-Default-1024x1024@1x.png" width="128" alt="Convene app icon">
</p>

<h1 align="center">Convene</h1>

<p align="center">
  An open-source Granola clone for macOS. Records your meetings, transcribes them live, and writes the notes into a folder you own.
</p>

## What it does

- Records both sides of a call: your mic and the other side's audio
- Transcribes live while the meeting runs, split by speaker
- Saves a Markdown note when you stop, with an AI summary and the full transcript
- Puts today's calendar in the menu bar. Click an event to join it and start recording
- Notices Zoom, Teams, Webex, Meet, and BlueJeans opening, and offers to record
- `⌥⇧R` records from anywhere, `⌥⇧K` flags a key moment mid-meeting
- Keys stay in your Keychain, notes stay in your folder. There's no Convene server

## Install

Needs macOS 15 (Sequoia) or later.

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

Crafted by [<img src="https://matthewblode.com/avatar-circle.png" width="20" align="top" />](https://matthewblode.com) [Matthew Blode](https://matthewblode.com)
