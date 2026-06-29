<p align="center">
  <img src="AppIcon-iOS-Default-1024x1024@1x.png" width="128" alt="Convene app icon">
</p>

<h1 align="center">Convene</h1>

<p align="center">
  Open-source meeting transcription for macOS. Bring your own API keys.
</p>

## How it works

- Records both sides of a call: your mic and the other side's audio
- Transcribes live as the meeting happens
- Take notes next to the transcript, get an AI summary when you stop
- Spots Zoom, Teams, Webex, Meet, BlueJeans, and Slack when they open
- Links recordings to your calendar (iCloud, Gmail, Fastmail, and more)
- Stays on your Mac. Notes save to a folder you pick, keys live in the Keychain
- `Option + Shift + R` to record, `Option + Shift + ,` for Settings

## Install

Needs macOS 15 (Sequoia) or later.

<strong><a href="https://github.com/mblode/convene/releases/latest">Download the latest release</a></strong>, or:

```bash
brew tap mblode/tap
brew install --cask convene
```

Add two keys in Settings. They're stored in your Keychain.

- **[AssemblyAI](https://www.assemblyai.com/)** for transcription. Get a key from the [dashboard](https://www.assemblyai.com/dashboard/api-keys).
- **[OpenAI](https://platform.openai.com/api-keys) or [Anthropic](https://console.anthropic.com/settings/keys)** for summaries. Optional. Claude works best.

On first launch Convene asks for Microphone, Screen Recording (audio only, no video), Calendar, and Notifications.

## Updates

Convene updates itself through Sparkle. Use **Check for Updates...** from the menu bar or Settings, or run `brew upgrade --cask convene`.

## Troubleshooting

Can't see the menu bar icon? Press `Option + Shift + ,` to open Settings.

No transcript? Make sure Screen Recording is on in **System Settings > Privacy & Security > Screen Recording**, then relaunch.

## Building from source

```bash
brew install xcodegen   # one-time
xcodegen generate       # refreshes Convene.xcodeproj
make install            # build and launch
```

Re-run `xcodegen generate` after adding a Swift file. See the [Makefile](Makefile) for more targets.

## License

MIT

---

Crafted by [<img src="https://matthewblode.com/avatar-sm.png" width="20" align="top" />](https://matthewblode.com) [Matthew Blode](https://matthewblode.com)
