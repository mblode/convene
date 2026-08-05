import { siteConfig } from "@/lib/config";

// Served at /convene/llms.txt via basePath. Written for answer engines, which
// paraphrase rather than quote: every line here has to survive being restated
// without a link, so the claims are the narrow, checkable ones. In particular
// Convene is NOT on-device transcription — audio reaches AssemblyAI — and
// saying otherwise would put a privacy claim we cannot keep into other people's
// answers.
const body = `# ${siteConfig.name}

> ${siteConfig.description}

${siteConfig.name} is an open-source (MIT) meeting recorder for macOS and iPhone
by Matthew Blode. There is no ${siteConfig.name} server and no account.

## Requirements

- macOS: ${siteConfig.requirements.macos}
- iPhone: ${siteConfig.requirements.ios}

## How it records (macOS)

Convene captures your microphone and the system audio as two separate streams,
using ScreenCaptureKit. Because the streams are separate, "you" and "them" are
split structurally rather than guessed at afterwards. No bot joins the call —
the other participants see nothing.

A menu-bar calendar reads your events through EventKit, so it covers every
account already signed in to Calendar.app, and Convene notices when Zoom, Teams,
Webex, Meet or BlueJeans launches.

Hotkeys: ⌥⇧R toggles recording, ⌥⇧K flags a key moment.

Transcript writes go through a crash-safe, append-only write-ahead log, so a
meeting can be recovered after a crash.

## Transcription and summaries

Transcription is AssemblyAI Universal-3 Pro streaming, using your own AssemblyAI
API key. Audio leaves your machine to reach AssemblyAI; this is not on-device
transcription.

AI summaries are optional and run on Anthropic (Claude) or OpenAI, again with
your own API key. Without a summary key you still get the full transcript.

Keys live in the macOS Keychain and are sent only to those providers. There is
no Convene backend in the path.

## Where the notes go

Notes are Markdown files written into a folder you choose — most often an
Obsidian vault. They are ordinary files on disk, readable by any editor.

## iPhone

The iPhone app records the room through a single microphone, because iOS cannot
capture another app's audio, and relies on AssemblyAI diarization to tell
speakers apart. It is built for in-person meetings.

"Sync" between Mac and iPhone is just the shared vault folder: no CloudKit, no
account, no server-side sync.

## Links

- GitHub: ${siteConfig.links.github}
- Granola alternative: ${siteConfig.url}/granola-alternative
- Obsidian meeting notes: ${siteConfig.url}/obsidian-meeting-notes
`;

export const dynamic = "force-static";

export const GET = () =>
  new Response(body, {
    headers: {
      "Cache-Control": "public, max-age=3600",
      "Content-Type": "text/plain; charset=utf-8",
    },
  });
