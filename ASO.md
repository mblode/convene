# App Store listing — Convene for iPhone

Every string App Store Connect asks for, kept here so it is version-controlled and re-pasteable.
Submission is **manual** — there is no fastlane and no App Store Connect API key in this repo — so
these get pasted in by hand at
<https://appstoreconnect.apple.com/apps/6795024762/distribution/ios/version/inflight>.

App Store Connect Apple ID: `6795024762`. Bundle ID: `co.blode.convene.mobile`.

Two things to watch when pasting:

- **Character limits** are enforced by App Store Connect, not by anything here. The count in each
  heading below is the limit; the count under it is what the current text actually uses.
- **The blockquotes are hard-wrapped** to keep this file readable in a diff. App Store Connect
  preserves newlines, so unwrap each paragraph back to one line when pasting — otherwise the
  product page shows the ragged right edge of this file.

---

## Name (≤30)

> Convene

7 characters. Deliberately left bare rather than padded to `Convene: AI Meeting Notes` — the name
field and the subtitle are indexed together, so the keywords go in the subtitle where they read as a
sentence instead of a stuffed title.

## Subtitle (≤30)

> AI meeting notes to Markdown

28 characters. Carries `meeting`, `notes` and `Markdown` into the index, which is why none of those
words appear in the keyword field.

## Keywords (≤100)

Comma-separated, **no spaces after the commas** — a space costs a character and buys nothing. No word
that already appears in the name or subtitle, since those are indexed anyway and repeating them wastes
the field.

```
transcribe,transcription,recorder,voice,audio,speech,dictation,summary,obsidian,offline,privacy
```

95 characters.

Deliberately absent: competitor names (Granola, Otter, Fireflies). Apple rejects keyword fields that
use another company's trademark.

## Promotional text (≤170)

Editable without submitting a new version, so this is the field to change for a launch or a sale.

> Put your iPhone on the table and hit record. Convene transcribes the room live, writes a summary when you stop, and saves it as Markdown in a folder you own.

157 characters.

## Description (≤4000)

2,196 characters.

> Convene records the meetings that aren't on a call. Put your iPhone on the table, hit record, and it
> transcribes the room as it goes, writes a summary the moment you stop, and saves the whole thing as
> a markdown file in a folder you own.
>
> There is no Convene server. Your API keys live in your iPhone's Keychain, audio goes to the
> transcription service you configure, and the notes are plain files on your device. Nothing routes
> through us, because there is no us to route through.
>
> **HOW IT WORKS**
> • Put the phone on the table and tap record — one microphone, everyone in the room
> • The transcript builds live and separates the speakers as it goes
> • Tap Key moment to flag something the second it's said
> • Type notes while you talk, in the same sheet
> • Stop, and an AI summary is written and saved with the transcript
>
> **YOUR NOTES, YOUR FOLDER**
> • Every meeting is a markdown file: summary, your notes, key moments, timestamped transcript
> • Point Convene at your Obsidian vault and meetings land there, syncing to the same vault on your Mac
> • Leave it alone and they stay in Convene's folder, under On My iPhone in the Files app
> • Delete a meeting and the file goes with it
> • Share any meeting as markdown from the detail view
>
> **BRING YOUR OWN KEYS**
> • AssemblyAI for transcription — required, and your account, not ours
> • Anthropic or OpenAI for summaries — optional, and only used if you turn summaries on
> • Keys are stored in the iOS Keychain and sent only to the service they belong to
> • No account to create, no subscription, no analytics, no tracking
>
> **BUILT FOR A REAL MEETING**
> • Keeps recording when the screen locks or you switch apps
> • Picks itself back up after a phone call interrupts it
> • Writes as it goes, so an interrupted meeting isn't a lost one
> • Search your meetings, grouped by day, newest first
>
> **ALSO ON MAC**
> Convene is open source and there's a macOS app too. On the Mac it records both sides of a call —
> your microphone and the other side's audio — puts today's calendar in the menu bar, and notices
> Zoom, Teams, Webex, Meet and BlueJeans opening to offer to record. Point both apps at the same
> vault and the notes meet in the middle.
>
> Free and open source: github.com/mblode/convene

## URLs

| Field | Value |
|---|---|
| Support URL | `https://blode.co/convene/support` |
| Marketing URL | `https://blode.co/convene` |
| Privacy Policy URL | `https://blode.co/convene/privacy` |

The privacy policy URL lives under **App Privacy**, not on the version page, and is also required on
the TestFlight **Test Information** page before external testing can start.

## Version and copyright

| Field | Value |
|---|---|
| Version | `1.0` |
| Copyright | `2026 Matthew Blode` |

`1.0` comes from `MARKETING_VERSION` under the `ConveneMobile` target in `project.yml`, which
overrides the shared `settings.base` value so the Mac app stays on its own number. The copyright
string matches `NSHumanReadableCopyright` in `ConveneMobile/Info.plist`.

---

## App Store Connect metadata

**App Information**

| Field | Value |
|---|---|
| Primary category | Productivity |
| Secondary category | Business |
| Content rights | Does not contain, show, or access third-party content |
| Age rating | 4+ |

**Pricing and Availability** — Free, all territories.

**Screenshots** — iPhone 6.9" only. `TARGETED_DEVICE_FAMILY: "1"` means the app is iPhone-only, so
Apple requires no iPad set and no other iPhone size. Generate them with `make screenshots`; captions
are defined in `screenshots/slides.json` and duplicated below, and the two must stay in sync because
Apple OCR-indexes screenshot text.

1. Record the room, transcribed live
2. Meeting notes saved as Markdown you own
3. AI summary written the moment you stop
4. Full transcript, split by speaker
5. Save straight into your Obsidian vault
6. Every meeting, searchable, on your phone

**App Privacy** — **Data Not Collected**. Nothing is transmitted to the developer: there is no
account, no Convene server, and no analytics or crash SDK in the binary (grep `Shared/` and
`ConveneMobile/` for `posthog|analytics|telemetry|sentry` — no hits). The AssemblyAI, Anthropic and
OpenAI calls run on the *user's own* API keys, so that data is collected by services the user
contracts with directly, not by or on behalf of Convene. The privacy policy spells those flows out in
full so the declaration doesn't read as evasive.

**Export compliance** — pre-answered by `ITSAppUsesNonExemptEncryption = false` in
`ConveneMobile/Info.plist`, which is why uploads never sit in "Missing Compliance". Don't remove it.

**App Review Information** — see `APP-REVIEW.md`.

---

## After launch

Promotional text and keywords are the two fields worth revisiting; both change without a new binary,
though keywords still need a version submission. Check Analytics → Sources for which search terms
actually convert, and rotate the weakest keyword out each month rather than rewriting the field.
