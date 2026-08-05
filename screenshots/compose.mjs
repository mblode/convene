#!/usr/bin/env node
/**
 * Composes App Store slides from the raw simulator captures.
 *
 * Renders `frame.html` in Chromium at exactly 1320x2868 — Apple's required 6.9" iPhone size — and
 * screenshots it, so the output needs no resizing and text stays vector-sharp.
 *
 * Usage: node screenshots/compose.mjs
 * Prereq: screenshots/capture.sh
 */
import { existsSync } from "node:fs";
import { copyFile, mkdir, readFile, rm } from "node:fs/promises";
import path from "node:path";

import { chromium } from "playwright";

const HERE = import.meta.dirname;
const RAW = path.join(HERE, "raw");
const OUT = path.join(HERE, "out");
const FONT_SOURCE = path.join(HERE, "../apps/web/public/glide-variable.woff2");

// Apple's 6.9" iPhone display slot, and the simulator's native resolution.
const WIDTH = 1320;
const HEIGHT = 2868;

const slides = JSON.parse(
  await readFile(path.join(HERE, "slides.json"), "utf-8")
);

if (!existsSync(RAW)) {
  console.error("No raw captures found. Run screenshots/capture.sh first.");
  process.exit(1);
}

const missing = slides
  .flatMap((slide) => slide.shots)
  .filter((shot) => !existsSync(path.join(RAW, shot)));
if (missing.length > 0) {
  console.error(`Missing captures: ${[...new Set(missing)].join(", ")}`);
  process.exit(1);
}

await rm(OUT, { force: true, recursive: true });
await mkdir(OUT, { recursive: true });

// The page loads the font relatively, so it has to sit beside frame.html. Read-only: the web app
// owns this file and nothing here writes back to it.
//
// A missing font is a warning rather than a failure. `frame.html` falls back to the system sans, so
// the slides still come out at the right size with readable captions — which beats failing the run
// outright when the marketing site has moved its assets around.
if (existsSync(FONT_SOURCE)) {
  await copyFile(FONT_SOURCE, path.join(HERE, "glide-variable.woff2"));
} else {
  console.warn(
    `Warning: ${path.relative(process.cwd(), FONT_SOURCE)} is missing — captions will use the system sans, not Glide.`
  );
}

const browser = await chromium.launch();
const page = await browser.newPage({
  deviceScaleFactor: 1,
  viewport: { height: HEIGHT, width: WIDTH },
});

await page.goto(`file://${path.join(HERE, "frame.html")}`);

// Deliberately sequential: there is one page, and each slide mutates it and then photographs it.
// Running these concurrently would have every slide racing to set the same three elements.
/* oxlint-disable no-await-in-loop */
for (const slide of slides) {
  await page.evaluate(
    ({ back, caption, front, theme }) => {
      document.body.dataset.theme = theme;
      document.querySelector("#caption").textContent = caption;
      document.querySelector("#shot-back").src = back;
      document.querySelector("#shot-front").src = front;
    },
    {
      back: `raw/${slide.shots[1]}`,
      caption: slide.caption,
      front: `raw/${slide.shots[0]}`,
      theme: slide.theme,
    }
  );

  // Fonts and both images must be decoded before the shutter, or the slide renders with fallback
  // type and blank device screens.
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all(
      [...document.images].map((image) =>
        image.complete ? Promise.resolve() : image.decode()
      )
    );
  });

  const file = path.join(OUT, `${slide.out}.png`);
  await page.screenshot({ path: file });
  console.log(`${slide.out}.png  ${slide.caption}`);
}
/* oxlint-enable no-await-in-loop */

await browser.close();
console.log(`\n${slides.length} slides in screenshots/out`);
