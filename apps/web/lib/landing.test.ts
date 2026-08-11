import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import { AnswerBlock } from "@/components/marketing/answer-block";
import { FAQ } from "@/lib/faq";
import {
  ANSWER_TEXT,
  COMPARISON,
  GRANOLA_UPDATED,
  OBSIDIAN_UPDATED,
  PAGE_UPDATED,
  PROOF_ROWS,
  SECTIONS,
} from "@/lib/landing";
import { homePageSchema } from "@/lib/structured-data";

/**
 * The contracts that hold this page together, each one guarding a failure that
 * is invisible by inspection.
 *
 * Everything here asserts against `renderToStaticMarkup` output rather than a
 * hydrated tree, on purpose. Server markup is what a crawler, an answer engine
 * and a reader with JS disabled actually receive. A test that passes against a
 * hydrated DOM will happily approve content none of those three can see, which
 * is precisely the class of bug these exist to catch.
 */

const WHITESPACE = /\s+/u;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/u;

const words = (text: string) => text.split(WHITESPACE).filter(Boolean).length;

describe("the answer block", () => {
  /**
   * 40-60 words. Under 40 and the paragraph has dropped the qualifier that made
   * it true; over 60 and an answer engine truncates it mid-clause, which quotes
   * you saying half of something.
   *
   * This is a real band, not a style preference — it is the reason the copy
   * lives in `lib/landing.ts` as a constant instead of inline in JSX, because a
   * string in JSX cannot be counted by anything.
   */
  it("stays inside the 40-60 word band", () => {
    expect(words(ANSWER_TEXT)).toBeGreaterThanOrEqual(40);
    expect(words(ANSWER_TEXT)).toBeLessThanOrEqual(60);
  });

  /** It must survive with nothing around it: an answer engine lifts the
   * paragraph alone, so a leading "It" or "The app" refers to a headline the
   * quote does not include. */
  it("opens with the product name rather than a pronoun", () => {
    expect(ANSWER_TEXT.startsWith("Convene")).toBe(true);
  });

  it("is present in the server-rendered markup", () => {
    const html = renderToStaticMarkup(AnswerBlock());
    // Apostrophes are entity-encoded on the way out, so compare on stretches
    // that have none rather than escaping the whole paragraph.
    expect(html).toContain("Convene records your meetings on macOS and iPhone");
    expect(html).toContain("No bot joins.");
  });
});

describe("every section heading", () => {
  /**
   * The whole point of the 11 August pass. A section heading that states a
   * conclusion ("No badges. Just the actual route.") is a good line and a bad
   * `h2`: nobody types it, so nothing matches it. The question goes in the
   * heading and the line survives at the front of the lede.
   *
   * Asserted rather than trusted because the swap is a copy convention with no
   * mechanism behind it — the next section somebody adds will follow whatever
   * the file already looks like, and this is what makes that true.
   */
  it("is phrased as a question", () => {
    for (const [name, section] of Object.entries(SECTIONS)) {
      expect(
        section.heading.endsWith("?"),
        `${name} heading is not a question`
      ).toBe(true);
    }
  });

  /** The display lines that used to be the `h2`. Each one is still on the page,
   * now opening its section's lede. This is the assertion that "nothing was
   * deleted" is a fact rather than an intention. */
  it("keeps the line it replaced, at the front of the lede", () => {
    expect(SECTIONS.dataFlow.lede).toContain(
      "No badges. Just the actual route."
    );
    expect(SECTIONS.howItWorks.lede).toContain(
      "From calendar to vault, without a detour."
    );
    expect(SECTIONS.setup.lede).toContain("Two minutes, once.");
    expect(SECTIONS.iphone.lede).toContain("For the meetings in a room.");
    expect(SECTIONS.faq.lede).toContain("Answers, not hedges.");
    expect(SECTIONS.closing.lede).toContain("Take the notes. Keep the files.");
  });
});

describe("the page dates", () => {
  it("are valid ISO dates", () => {
    for (const date of [PAGE_UPDATED, GRANOLA_UPDATED, OBSIDIAN_UPDATED]) {
      expect(date).toMatch(ISO_DATE);
      expect(Number.isNaN(Date.parse(date))).toBe(false);
    }
  });

  /** A last-updated stamp in the future is worse than none: it is the one thing
   * on the page a reader can prove is wrong without leaving it. */
  it("are not in the future", () => {
    for (const date of [PAGE_UPDATED, GRANOLA_UPDATED, OBSIDIAN_UPDATED]) {
      expect(Date.parse(date)).toBeLessThanOrEqual(Date.now());
    }
  });

  it("reaches WebPage.dateModified", () => {
    const webPage = homePageSchema(FAQ)["@graph"].find(
      (node) => node["@type"] === "WebPage"
    ) as { dateModified?: string } | undefined;
    expect(webPage?.dateModified).toBe(PAGE_UPDATED);
  });
});

describe("the proof list", () => {
  /** A fact with no link is a badge, which is the thing this block replaced.
   * Every row has to be checkable or it should not be on the page. */
  it("gives every row somewhere to check it", () => {
    for (const row of PROOF_ROWS) {
      expect(row.href, `${row.term} has no source`).toMatch(/^https:\/\//u);
    }
  });
});

describe("the comparison table", () => {
  /** Every row has to fill every column, or a reader sees a blank cell and
   * reads it as "we would rather not say". */
  it("fills every column in every row", () => {
    for (const row of COMPARISON.rows) {
      expect(row.values, `${row.label} is short a cell`).toHaveLength(
        COMPARISON.columns.length
      );
    }
  });

  /** A comparison with no losing row reads as marketing and gets discounted
   * entirely, including the rows that were true. This one names what Granola
   * does better and recommends it, and that sentence is not decoration. */
  it("keeps the sentence that recommends the competitor", () => {
    expect(COMPARISON.honesty).toContain(
      "Granola is good and you should use it"
    );
  });
});
