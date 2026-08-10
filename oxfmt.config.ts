import { defineConfig } from "oxfmt";
import ultracite from "ultracite/oxfmt";

export default defineConfig({
  ...ultracite,
  ignorePatterns: [
    ...(ultracite.ignorePatterns ?? []),
    "**/*.md",
    "**/*.mdx",
    // Xcode asset catalogs and app icon bundles are tooling output, not source
    // we author by hand. Formatting Contents.json / icon.json churns huge trees
    // for no review value.
    "**/Assets.xcassets/**/Contents.json",
    "**/AppIcon.icon/**",
    // Golden fixtures and screenshot chrome should stay byte-stable.
    "**/ConveneTests/Fixtures/**",
    "**/convene-tests/Fixtures/**",
    "**/screenshots/frame.html",
  ],
});
