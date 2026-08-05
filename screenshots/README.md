# App Store screenshots

Two steps: capture real screens from the simulator, then frame them.

```sh
make screenshots            # both steps
```

or, separately:

```sh
screenshots/capture.sh      # raw/*.png   (~2 min)
node screenshots/compose.mjs # out/*.png
```

Upload `out/*.png` to App Store Connect under the **6.9" iPhone** display size. Both `raw/` and
`out/` are gitignored — regenerate rather than commit.

## How it works

`capture.sh` creates a "Convene AppStore 6.9" simulator (iPhone 17 Pro Max, whose native 1320×2868
is exactly Apple's 6.9" requirement), pins the status bar to 9:41 with full signal and battery, then
runs `ConveneMobileUITests/ScreenshotCaptureTests`. Screenshots leave the simulator as XCTest
attachments, so the script pulls them out of the result bundle with `xcresulttool export
attachments`.

`compose.mjs` renders `frame.html` in Chromium at 1320×2868 and screenshots it — no resizing, so
caption text stays vector-sharp. Slides are defined in `slides.json` (captions, which raw shots to
pair, light or dark).

The seven raw captures are `01-record`, `02-detail`, `03-summary`, `04-transcript`, `05-settings`,
`06-library-dark` and `07-detail-dark`; the six slides pair them up.

## Gotchas

- **Debug build only.** The seeded fixture is behind `#if DEBUG`
  (`ConveneMobile/Debug/ScreenshotFixture.swift`); a Release build lands on `WelcomeView` with an
  empty library.

- **This build is signed, unlike `make ios-build` and `make ios-run`.** Those pass
  `CODE_SIGNING_ALLOWED=NO`, and an unsigned simulator build is refused by the Keychain
  (`errSecMissingEntitlement`). The fixture stores placeholder API keys there, so without signing
  Settings shows "Could not save the key to Keychain" in red and the record button raises the
  add-a-key sheet instead of the recording sheet.

- **The app is uninstalled before the run.** A meeting's filename is built from its start time, and
  the two meetings dated "today" move with the clock — so yesterday's markdown is never overwritten,
  and the library, which reads every file it finds, shows the whole set twice. The fixture also
  empties its own two directories on each launch; the uninstall is the belt to that pair of braces.

- **`CONVENE_UI_TEST_LIVE_MEETING` is separate from `CONVENE_UI_TEST_SCREENSHOT_MODE`.** It poses a
  meeting as running, which turns the floating record pill red and starts its clock — right for
  slide 1, wrong for every other slide that shows the list. Only `testCaptureLightScreens` passes
  it.

- **The recording sheet goes last** in the light run. It is the only capture that leaves a sheet on
  screen, and its dismissal is the flakiest step here.

- **The sheet opens at half height and has to be dragged up.** The app promotes the detent itself on
  the first transcribed turn, but the fixture's transcript is already there when the sheet opens, so
  nothing changes and nothing promotes.

- **Scroll positions are set with inertia-free drags, not `swipeUp()`.** A fling lands somewhere
  different on every run — usually with a line of body text sliced in half behind the floating
  toolbar, which reads as a rendering bug in a store listing. See `scroll(_:bringing:toFraction:)`.

- **API key fields photograph blank.** iOS excludes `SecureField` contents from screen captures.
  The green "Saved" tick beside each row is what carries the meaning, which is the right thing for
  a store listing anyway.

- UI tests are flaky in parallel, so the script passes `-parallel-testing-enabled NO`.

## Changing the slides

Edit `slides.json` for captions and pairings, `frame.html` for the frame itself. Captions are
OCR-indexed by Apple, so keep them one line each with the keyword first.

To add a new screen, add a `capture*` step to `ScreenshotCaptureTests.swift` and reference its
attachment name from `slides.json`. To change what the screens *show*, edit the fixture data in
`ScreenshotFixture.swift` — meetings are written through the real `MeetingFileWriter` /
`MarkdownRenderer` path, so what a slide shows is what a recorded meeting produces.

`frame.html` needs the Glide face; `compose.mjs` copies it from `apps/web/public/glide-variable.woff2`
beside the page each run. Colours come from `apps/web/app/globals.css` and
`ConveneMobile/UI/Theme/Palette.swift`.
