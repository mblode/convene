# App Review Information — Convene for iPhone

What goes in the **App Review Information** panel on the version page, and in **Beta App Review
Information** on the TestFlight Test Information page. Kept here so the wording survives between
submissions.

---

## Sign-in

**Sign-in required: NO.** There is no account system anywhere in Convene — no login, no server, no
identity. Leave the demo account fields empty; filling them in with something fake is worse than
leaving them blank.

## The thing that actually gets this rejected

Convene is bring-your-own-key. **Without an AssemblyAI API key the reviewer cannot record anything** —
they reach the setup checklist on the root screen and stop, because `SetupState.swift` computes
`canRecord = hasTranscriptionKey && microphone != .denied`. App Review rejects what it cannot
exercise, and "the user supplies their own key" is not an accepted answer on its own.

So the **Notes** field must contain a live AssemblyAI key. Provision a key that exists only for
review, note it in the password manager as such, and rotate it after the version is approved. The
same applies to the TestFlight Beta App Review notes.

> **The key is not stored in this repo.** Paste it into App Store Connect directly. If you are
> reading this because a submission was rejected for "we were unable to review your app", the key in
> the notes has almost certainly expired or been rotated.

## Contact information

| Field | Value |
|---|---|
| First name | Matthew |
| Last name | Blode |
| Phone | +61 456 455 551 |
| Email | m@blode.co |

---

## Notes (paste verbatim, then add the key on the first line)

> ASSEMBLYAI API KEY FOR REVIEW: <paste key here>
>
> HOW TO SET UP (about 30 seconds)
> 1. Launch the app and tap Get started on the welcome screen.
> 2. Open Settings from the meetings list.
> 3. Paste the key above into the AssemblyAI field. The setup checklist on the root screen clears.
> 4. Tap the record button, allow the microphone when prompted, and speak. The transcript appears
>    live. Tap stop to save.
>
> There is no account, no sign-in, and no in-app purchase. The app is free and open source
> (github.com/mblode/convene).
>
> ANTHROPIC / OPENAI KEYS ARE OPTIONAL
> They power the AI summary written when a recording stops, and nothing else. Recording, live
> transcription and saving all work without them. If you would like to review the summary feature as
> well, let us know and we will supply a key.
>
> WHY THE APP REQUESTS THE MICROPHONE
> It records the room. Audio is streamed to AssemblyAI for transcription using the key entered above
> and is not sent anywhere else. There is no Convene server.
>
> WHY THE APP DECLARES THE AUDIO BACKGROUND MODE
> A meeting is recorded with the phone face-down on a table. Capture has to survive the screen
> locking, the reviewer switching apps to take a note, and an incoming call interrupting the
> session — all three are ordinary during a real meeting, and without the audio background mode the
> recording is silently truncated. The app does not play audio in the background and does not use the
> mode for anything else.
>
> WHERE RECORDINGS ARE SAVED
> Each meeting is written as a markdown file — summary, notes, key moments, and a timestamped
> transcript. By default they go to the app's own Documents folder, visible in the Files app under
> On My iPhone > Convene. In Settings, Choose your vault opens a folder picker so the files can be
> written to an Obsidian vault or iCloud Drive instead. Deleting a meeting in the app deletes its
> file.
>
> DATA COLLECTION
> None. There is no account, no analytics SDK, and no crash reporting in the binary. API keys are
> stored in the iOS Keychain and each key is sent only to the service it belongs to. This is why the
> App Privacy declaration is Data Not Collected — the full data flows are described at
> https://blode.co/convene/privacy.

---

## Beta App Review (TestFlight, external testing)

Same contact details, same notes. External TestFlight testing needs one round of Beta App Review;
after it passes, later builds of the same version go out without re-review.

The **Beta App Description** shown to testers in the TestFlight app:

> Convene records the meetings that aren't on a call. Put your iPhone on the table, hit record, and it
> transcribes the room live, writes an AI summary when you stop, and saves the whole meeting as a
> markdown file in a folder you own.
>
> You need your own AssemblyAI API key to transcribe — it's free to start, and the key lives in your
> iPhone's Keychain. An Anthropic or OpenAI key is optional and only powers the summary.
>
> WHAT TO TEST
> • First run: paste an AssemblyAI key in Settings and get through the setup checklist
> • Record a real meeting with the phone on the table, and see whether the speaker separation holds up
> • Lock the screen mid-recording, switch apps, and take a phone call — recording should survive all three
> • Tap Key moment during a meeting and check it appears in the saved file
> • Point Settings > Choose your vault at an Obsidian vault or iCloud Drive, and confirm the markdown
>   syncs to your Mac
> • Compare summaries from Claude and from OpenAI
> • Share a meeting as markdown, and delete one (it removes the file too)
> • Rename or move your vault folder while the app is closed, then reopen Settings — it should warn you
>
> Feedback: m.blode@gmail.com, or shake the phone to send it through TestFlight.

Feedback email: `m.blode@gmail.com`. Marketing URL: `https://blode.co/convene`. Privacy policy URL:
`https://blode.co/convene/privacy` — required before external testing can be submitted.
