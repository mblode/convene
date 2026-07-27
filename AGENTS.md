# AGENTS.md

Convene: a macOS menu-bar app (`Convene`) and an iPhone app (`ConveneMobile`), both Swift/SwiftUI
over a shared `Shared/` layer, with a Next.js marketing site in `apps/web`. The Xcode project is
generated from `project.yml` by xcodegen — it is not checked in.

## Setup

```sh
brew install xcodegen           # required: Convene.xcodeproj is generated, not committed
npm install                     # web only (apps/web)
```

## Swift commands

```sh
make project      # regenerate Convene.xcodeproj from project.yml
make debug        # Debug build of the Mac app (ad-hoc signed)
make build        # Release build of the Mac app
make install      # Debug build -> /Applications/Convene.app -> relaunch
make test         # unit tests (ConveneTests, macOS destination)
make ios-build    # Debug build of the iPhone app for the simulator
make ios-run      # build, boot the simulator, install, launch (IOS_SIMULATOR ?= iPhone 17)
make ios-archive  # fresh TestFlight archive; BUMP=1 bumps the iOS build number first
make clean        # rm the derived-data dirs
```

Release-only: `make archive`, `make export`, `make dmg`, `make notarize` (needs a real Developer ID
identity, `APPLE_TEAM_ID`, and notarytool credentials).

## Web commands

Run from the repo root (turbo) or `apps/web` directly.

```sh
npm run dev           # next dev via portless
npm run build
npm run lint          # oxlint
npm run format        # oxfmt --write
npm run check-types   # tsc --noEmit
```

## Formatting

`lefthook` runs oxfmt/oxlint on staged JS/TS/JSON/CSS, and `swift-format` on staged `*.swift`, at
pre-commit.

```sh
make format         # format Swift in place (config: .swift-format)
make format-check   # non-mutating, same rule CI applies
```

CI lints only the Swift files a push or PR *changes*, not the whole tree. The ~10k lines written
before `.swift-format` existed do not satisfy it; the pre-commit hook formats each file the first
time it is staged, so the compliant set grows one touched file at a time. Do not "fix" this with a
repo-wide reformat — it would bury every real change in whitespace.

`Convene/UI/Theme/Color+Theme.swift` and `Convene/UI/Settings/Pages/PermissionsPage.swift` carry
`// swift-format-ignore-file`: their `=` columns are hand-aligned to read as tables and
swift-format collapses that. Don't remove the directive to "fix" their formatting.

## Gotchas

- **New Swift file → run `make project` (or `xcodegen generate`) first.** `Convene.xcodeproj` is
  generated and gitignored, so a file you just added is in no target until you regenerate.
  *Symptom:* "cannot find X in scope" / "cannot find type X" for a file that plainly exists on disk.
  `make build`/`test`/`ios-build` run `project` for you; building from Xcode does not.

- **`Shared/` must not import AppKit or UIKit.** It is listed as a source path under *both* the
  `Convene` (macOS) and `ConveneMobile` (iOS) targets in `project.yml`, so one `import AppKit` there
  breaks the iOS build. Today `Shared/` is Foundation/SwiftUI only, with zero `#if os(...)` — keep
  it that way; put platform UI under `Convene/` or `ConveneMobile/`.
  *Symptom:* iOS build fails with "no such module 'AppKit'" while the Mac build is green.

- **Never add `temperature`, `top_p`, `top_k`, or a `budget_tokens` thinking config to the Claude
  request body.** The models offered reject them — see the comment above the request body in
  `Shared/Summary/ClaudeSummaryService.swift`. `max_tokens` there is deliberately generous because
  thinking is on by default and shares that budget; a truncated reply fails JSON parsing outright.
  *Symptom:* HTTP 400 from the API, or "no summary" with a decode error in the log.

- **Archives must land in `~/Library/Developer/Xcode/Archives/`.** Use
  `installer/release-archive.sh` (`make ios-archive`), which writes a dated archive there and prints
  the version, build number, and encryption flag. A bare `xcodebuild archive -archivePath /tmp/...`
  builds fine but the archive never shows up in Organizer, so you cannot distribute it.
  *Symptom:* archive succeeds, Window > Organizer is empty or shows only the previous build.

- **The iOS target has its own `CURRENT_PROJECT_VERSION`,** set under the `ConveneMobile` target in
  `project.yml`, separate from the shared `settings.base` one. TestFlight rejects a build number it
  has seen, so this climbs on every upload — and it must not drag the Mac app's build number along.
  Bump it with `make ios-archive BUMP=1`, and commit the `project.yml` change.
  *Symptom:* App Store Connect rejects the upload with "build number already exists", or the Mac
  app's version jumps for no reason.

- **When distributing, uncheck "Automatically manage version and build number".** Otherwise Xcode
  increments the number on a possibly stale archive: the number climbs, the code doesn't, and your
  fixes never reach TestFlight.
  *Symptom:* a TestFlight build whose number is new but whose behaviour is the previous build's.

- **`ITSAppUsesNonExemptEncryption=false` in `ConveneMobile/Info.plist` is deliberate.** It skips the
  export-compliance questionnaire on every TestFlight upload. Don't remove it.
  *Symptom:* every upload sits in "Missing Compliance" until you answer the prompt by hand.

- **Deployment targets: macOS 15.0, iOS 17.0.** Liquid Glass APIs in `ConveneMobile` are gated behind
  `if #available(iOS 26.0, *)` (see `ConveneMobile/UI/Theme/LiquidGlass.swift`); anything newer than
  the deployment target needs the same gate.
  *Symptom:* "is only available in iOS 26.0 or newer" at compile time.

- **`ConveneTests` is a macOS-only bundle that depends on the `Convene` target.** Shared code is
  tested through the Mac app; there is no iOS test target, so `make test` will not catch an
  iOS-specific break. Verify with `make ios-build`.
