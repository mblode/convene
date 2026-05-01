# Convene website

Marketing landing page for [Convene](https://github.com/mblode/convene), the macOS meeting-transcription app. A single page that fetches the latest GitHub release server-side and surfaces a `.dmg` download.

Deployed at [convene.blode.co](https://convene.blode.co).

## Develop

```bash
npm install
npm run dev
```

Open http://localhost:3000.

## Scripts

```bash
npm run build         # production build
npm run start         # serve the production build
npm run check-types   # tsc --noEmit
npm run lint          # biome check
npm run lint:fix      # biome check --write
```

## Stack

- Next.js 16 (App Router, React Compiler, Turbopack)
- React 19
- Tailwind CSS v4 with the Tatem dark + Sky Gradient visual system
- Glide variable font (`public/glide-variable*.woff2`)
- Biome + ultracite for lint and format
- Vercel for hosting (production tracks `main`)

## Layout

```
app/
  layout.tsx        Glide font load, metadata, Agentation dev toolbar
  page.tsx          Hero + download CTA, fetches latest GitHub release
  globals.css       Tatem theme tokens (colors, type scale, gradient)
  manifest.json     PWA manifest
components/
  site-footer.tsx   Author + version + GitHub link
  ui/button.tsx     shadcn Button (unused on the landing — kept for future pages)
lib/
  config.ts         Site version + external links
public/             Fonts, app icon, manifest icons
```

## Download CTA

`app/page.tsx` calls `https://api.github.com/repos/mblode/convene/releases/latest` on the server (revalidate: 3600). It picks the first asset ending in `.dmg`, falls back to the GitHub releases page if the API call fails. No code change is needed when you cut a new Convene release — tag, push, and the page picks it up within the hour.

## Visual system

Tokens live in `app/globals.css` via Tailwind v4 `@theme`:

- Colors: `--color-twilight-ink`, `--color-polar-white`, `--color-pewter-mist`, `--color-silver-tone`, `--color-obsidian-grey`, `--color-charcoal-black`, `--color-mist-grey`, `--color-cerulean-accent`
- Type scale: `text-caption` (13), `text-body` (16), `text-subheading` (20), `text-display` (40), each with matching line-height and letter-spacing
- Hero gradient: `var(--gradient-sky)`

Prefer the named utilities (`text-polar-white`, `bg-twilight-ink`, `text-display`) over arbitrary hex values.

## Deploy

Pushed to Vercel via the linked project — production deploys run on every push to `main`, previews on every PR. No environment variables required.

## Updating icons

`public/app-icon.png`, `public/web-app-manifest-{192,512}.png`, `app/apple-icon.png`, `app/favicon.ico`, `app/icon0.svg`, and `app/icon1.png` should be regenerated from the Convene macOS app icon source at `../Convene/Assets.xcassets/AppIcon.appiconset/` whenever the app icon changes.
