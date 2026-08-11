import { siteConfig } from "@/lib/config";

/**
 * The copy the home page makes claims with, as constants rather than JSX.
 *
 * Two failures this prevents, both of which have already cost somebody an
 * afternoon elsewhere in this fleet. A claim written inline in JSX cannot be
 * asserted by a test, so the answer paragraph drifts out of its word band and
 * nobody notices until an answer engine truncates it mid-clause. And a
 * `dateModified` derived from a build clock claims every page changed on every
 * deploy, which is a freshness signal that means nothing.
 *
 * So: constants here, `lib/landing.test.ts` holds them to their contracts, and
 * the components are markup.
 */

/**
 * The liftable answer. An answer engine asked "what is Convene" will quote one
 * paragraph or none, so this one has to stand alone with no antecedent — no
 * "it", no "the app", no reference to the headline above it.
 *
 * 40-60 words is the band, asserted in `lib/landing.test.ts`. Under 40 and it
 * has dropped the qualifier that made it true; over 60 and it gets cut
 * mid-clause, which quotes you saying half of something.
 */
export const ANSWER_QUESTION = "What is Convene?";

export const ANSWER_TEXT =
  "Convene records your meetings on macOS and iPhone and writes the notes into a folder you own. Your microphone and your Mac's system audio run as two separate streams, transcribed live on your own AssemblyAI key. Each meeting lands as a Markdown file with frontmatter, a summary, key moments, and a timestamped transcript. No bot joins.";

/** "no account" is deliberately not here. The closing CTA is the one place on
 * the page that keeps it, because that is where somebody is deciding rather
 * than reading. */
export const ANSWER_NOTE = "Free, MIT licensed. Requires macOS 15 or later.";

/**
 * Bumped when the answer, an FAQ answer, or a comparison claim changes. Not
 * when a class name moves.
 *
 * Hand-written rather than `new Date()` or a git mtime, and the reason is in
 * both of those alternatives: a build clock marks the page as changed on every
 * deploy, and an mtime marks it as changed when a formatter touches it. Two
 * surfaces read this one constant — `WebPage.dateModified` and `sitemap.ts` —
 * so they cannot disagree with each other.
 */
export const PAGE_UPDATED = "2026-08-11";

/**
 * The same stamp for the two long-form pages, one constant each.
 *
 * `sitemap.ts` used to share a single `lastModified` across all three URLs,
 * which said all three changed together every time any one of them did. That is
 * false, and it is the signal a crawler uses to decide how often to come back,
 * so the page that genuinely changed got the same weight as the two that did
 * not.
 *
 * These two stay on 5 August deliberately. The 11 August pass moved their FAQ
 * out of an accordion and gave each question an anchor — markup, not content.
 * Not a word of either page's copy changed, so neither did its date. A
 * last-modified that moves when a class name moves is a last-modified nobody
 * can use.
 */
export const GRANOLA_UPDATED = "2026-08-05";
export const OBSIDIAN_UPDATED = "2026-08-05";

/**
 * Every section heading on the home page, as the question somebody would type.
 *
 * `SectionHeading` used to render the display line as the `h2` and the eyebrow
 * as a small label above it. The slots are now swapped: the question is the
 * `h2` and the display line opens the lede. Nothing was deleted in that move —
 * every line that used to be a heading is still on the page, one element down,
 * doing the job it was written for, which was to be the sentence a person
 * remembers rather than the string a machine matches.
 */
export const SECTIONS = {
  closing: {
    /** "Take the notes. Keep the files." survives as the first line of the
     * lede — it is the best sentence on the site and the question above it
     * exists to be matched, not to replace it. */
    heading: "Ready to take the notes and keep the files?",
    lede: "Take the notes. Keep the files. Free, MIT licensed, no account. The next meeting can write itself down.",
  },
  comparison: {
    heading: "How does Convene compare to Granola?",
  },
  dataFlow: {
    heading: "Where does my audio actually go?",
    lede: "No badges. Just the actual route.",
  },
  faq: {
    heading: "What do people ask before installing?",
    lede: "Answers, not hedges. Including the awkward ones.",
  },
  /** No `handoff` entry any more. "How do I know the note matches what was
   * said?" was an `h2` and a lede whose only job was to caption `HandoffMock`,
   * and the mock makes that argument on its own. The mock moved into the "After"
   * step of `howItWorks`, where it replaces `MarkdownNoteMock` — it shows the
   * note *and* the transcript it came from, in fewer words than the note mock
   * spent showing the note alone. The one fact the lede carried, that the line
   * spoken at 00:44 becomes the action item and links back to that second, is
   * now in that step's body. */
  howItWorks: {
    heading: "How does a meeting become a note?",
    lede: "From calendar to vault, without a detour.",
  },
  iphone: {
    heading: "Does Convene work on iPhone?",
    lede: "For the meetings in a room. iOS will not let an app capture another app's audio, so the phone records the room and splits the speakers afterwards. Same vault as your Mac.",
  },
  promises: {
    heading: "What is different about the way Convene records?",
    lede: "All three follow from recording on your Mac rather than sending something into the call.",
  },
  proof: {
    heading: "What is shipped today?",
  },
  setup: {
    heading: "What do I need to set up?",
    /** "No account to create." was here and is not any more. The claim is made
     * four times on this page; the closing CTA keeps it, because that is where
     * somebody is deciding, and `COMPARISON.honesty` keeps it because the
     * sentence needs it to land. This was the weakest of the four. */
    lede: "Two minutes, once. All Convene needs is a transcription key.",
  },
} as const;

/**
 * Proof, as a list of things somebody can go and verify.
 *
 * This replaced a `TrustStrip` of four unlinked phrases, and its docblock is
 * carried forward here because the reasoning still governs: only claims a
 * visitor could check for themselves, no star count, no user number, no
 * compliance badge — this audience punishes an unsourced figure harder than it
 * rewards one. The repository has one star. A page that renders "1" beside a
 * download button has spent real credibility to say nothing.
 *
 * What the strip could not do is prove any of it, so every row now carries the
 * link a reader would check it with, and two `siteConfig.links` that had been
 * sitting in config unused finally point at something.
 *
 * "Sandboxed" is claimed here and it is true — `apps/convene/Convene.entitlements`
 * carries `com.apple.security.app-sandbox` set to `true`. It is checked rather
 * than assumed because the same phrase was headed for Commandment's page, whose
 * entitlements file has no such key; one word of polish, one false statement.
 */
const REPO = siteConfig.links.github;

export const PROOF_CLOSING =
  "Convene is built by Matthew Blode, one person in Melbourne. No case studies and no customer logos, because there is no roster yet.";

/**
 * Every row is shorter than it was and no row is gone, because a row here is a
 * claim plus the one link that checks it — cutting one costs a fact and a
 * source, which is the one thing this pass was not allowed to do.
 *
 * Two rows absorbed a retired FAQ answer instead. "What happens if my Mac
 * crashes mid-meeting?" ended with the recovery step, so this row now carries
 * it. "Who makes Convene?" is why `PROOF_CLOSING` names him.
 */
export const PROOF_ROWS = [
  {
    detail: "MIT. Read it, fork it, ship it.",
    href: `${REPO}/blob/main/LICENSE.md`,
    term: "Licence",
  },
  {
    detail:
      "Sandboxed, signed with a Developer ID certificate, notarised by Apple, and self-updating through Sparkle.",
    href: `${REPO}/blob/main/apps/convene/Convene.entitlements`,
    term: "The Mac app",
  },
  {
    detail:
      "Your AssemblyAI key goes into the macOS Keychain, never a config file and never a Convene server.",
    href: siteConfig.links.keychainSource,
    term: "Key storage",
  },
  {
    detail:
      "Every confirmed transcript segment and key moment is flushed to an append-only log as it goes, so a crash costs about two seconds. The next launch turns the log into a normal note.",
    href: siteConfig.links.walSource,
    term: "If your Mac crashes",
  },
  {
    detail:
      "On TestFlight, not on the App Store. It records the room through the phone's microphone.",
    href: siteConfig.links.testflight ?? siteConfig.links.github,
    term: "The iPhone app",
  },
  {
    detail: `${siteConfig.requirements.macos}, on Apple silicon or Intel. The iPhone app needs ${siteConfig.requirements.ios}.`,
    href: siteConfig.links.releases,
    term: "Requirements",
  },
] as const;

/**
 * The homepage comparison.
 *
 * Every row here is already published on `/granola-alternative`, copied across
 * word for word, so this block asserts nothing new and there is exactly one
 * place where a Granola claim is researched. `COMPARED_ON` is imported by that
 * page rather than restated, because two hand-maintained copies of a
 * checked-on date is how one of them silently becomes a lie.
 *
 * The date is deliberately *not* today's. It is the day those cells were
 * actually read off Granola's pricing and product pages. Bumping it to the day
 * this table was built would claim a check nobody performed, which is the one
 * failure a dateline exists to prevent.
 *
 * One row is missing that `/granola-alternative` still carries: "Bot joins the
 * call", which read "No" against "No". A row both columns agree on is not a
 * comparison, it is a line of table asking to be read. The claim itself is not
 * lost — the hero subhead, the answer block and the first promises card all
 * make it, and the long-form page keeps the row because a reader who came for a
 * feature-by-feature table wants the ties in it too.
 *
 * `honesty` is the full existing answer to "How is this different from
 * Granola?", carried here verbatim when that FAQ entry was retired — see the
 * note at the top of `lib/faq.ts`. A comparison with no losing row reads as
 * marketing and gets discounted entirely, including the rows that were true.
 */
export const COMPARED_ON = "5 August 2026";

export const COMPARISON = {
  columns: ["Convene", "Granola"],
  honesty:
    "Granola is a polished commercial product with a team behind it, an App Store iPhone app, and integrations Convene does not have. It also stores your notes on its servers. Convene is the open-source option for people who want the notes to be files they own, with no account and no vendor in the middle. If you would rather pay someone to run it for you, Granola is good and you should use it.",
  rows: [
    {
      label: "Source code",
      values: ["Open source, MIT", "Closed source"],
    },
    {
      label: "Where notes live",
      values: [
        "Markdown files in a folder you pick",
        "In Granola's app and on its servers",
      ],
    },
    {
      label: "Account",
      values: ["None (no account exists)", "Required"],
    },
    {
      label: "Price",
      values: [
        "Free. You pay AssemblyAI and, optionally, Anthropic or OpenAI directly",
        "Free tier, then a paid plan per user",
      ],
    },
    {
      label: "Integrations",
      values: [
        "None. It writes files, so use whatever reads files",
        "Notion, Slack, HubSpot, Affinity, Zapier and more on paid plans",
      ],
    },
  ],
} as const;
