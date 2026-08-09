/** The site is served as a sub-path of blode.co, not at its own root. */
export const basePath = "/convene";

/** basePath covers next/link, next/image and route handlers. It does NOT cover
 * raw <a href>, <img src>, or manifest icons — those go through this. */
export const asset = (path: string) => `${basePath}${path}`;

/** Falls back to the real MARKETING_VERSION in project.yml when the
 * unauthenticated GitHub API is rate-limited (60 req/hr/IP). */
export const fallbackVersion = "v0.1.9";

export const siteConfig = {
  brewCommand: "brew install --cask convene",
  description:
    "Convene records both sides of your call, transcribes it live, and writes the note into a folder you own. Open source, no meeting bot, no Convene server.",
  links: {
    assemblyai: "https://www.assemblyai.com/",
    author: "https://blode.co",
    github: "https://github.com/mblode/convene",
    /** Source deep-links: a checkable claim beats a compliance badge. */
    keychainSource:
      "https://github.com/mblode/convene/blob/main/packages/shared/Keychain/KeychainManager.swift",
    persistenceSource:
      "https://github.com/mblode/convene/tree/main/packages/shared/Persistence",
    releases: "https://github.com/mblode/convene/releases",
    /** Set to the public TestFlight URL once Beta App Review has passed. The
     * iPhone section renders a "not yet open" variant while this is null. */
    testflight: "https://testflight.apple.com/join/ZphcgfD7" as string | null,
    walSource:
      "https://github.com/mblode/convene/blob/main/packages/shared/Persistence/TranscriptWALService.swift",
  },
  name: "Convene",
  requirements: {
    ios: "iOS 17 or later",
    macos: "macOS 15 or later",
  },
  url: "https://blode.co/convene",
} as const;
