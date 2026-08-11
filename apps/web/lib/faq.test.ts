import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it } from "vitest";

import { FaqSection } from "@/components/marketing/faq-section";
import { FAQ } from "@/lib/faq";
import { SECTIONS } from "@/lib/landing";
import { homePageSchema } from "@/lib/structured-data";

/**
 * The FAQ and the FAQPage node must say the same thing.
 *
 * The failure this prevents: someone improves an answer in `lib/faq.ts` and the
 * rendered copy moves while `acceptedAnswer.text` does not, or an answer is
 * rendered behind something a reader has to open. Google calls markup that
 * asserts an answer the reader cannot see a mismatch, and the penalty is that
 * the whole node stops being trusted — including the entries that were fine.
 *
 * That is not hypothetical here. This FAQ shipped for months inside an
 * `Accordion` whose collapsed panels stayed in the DOM at `opacity-0`, which is
 * the one configuration where reading the HTML tells you everything is fine.
 */

const CLAUSE_END = /[.,;:]/u;
const PUNCTUATION = /[^a-z ]/gu;

/** Compares on words, so "How does Convene compare to Granola?" and "How is
 * this different from Granola?" are not treated as the same string — they are
 * not, and the duplication that matters is the exact one. */
const normalise = (text: string) =>
  text.toLowerCase().replace(PUNCTUATION, "").trim();

const PAGE_ANCHOR = /^https:\/\/blode\.co\/convene#[a-z0-9-]+$/u;

const html = renderToStaticMarkup(FaqSection());
const faqNode = homePageSchema(FAQ)["@graph"].find(
  (node) => node["@type"] === "FAQPage"
) as {
  mainEntity: {
    acceptedAnswer: { text: string; url: string };
    name: string;
  }[];
};

describe("every FAQ answer", () => {
  it("is in the server-rendered markup, not behind a disclosure", () => {
    for (const entry of FAQ) {
      // The first clause of each answer, which is enough to prove the text was
      // rendered and short enough to avoid the entity-encoding of apostrophes.
      const [opening] = entry.answer.split(CLAUSE_END);
      expect(
        html,
        `answer for "${entry.question}" is missing from server markup`
      ).toContain(opening);
    }
  });

  it("matches the text the graph publishes", () => {
    for (const entry of FAQ) {
      const question = faqNode.mainEntity.find(
        (q) => q.name === entry.question
      );
      expect(question, `no schema entry for "${entry.question}"`).toBeDefined();
      expect(question?.acceptedAnswer.text).toBe(entry.answer);
    }
  });
});

describe("every FAQ question", () => {
  it("is rendered as a heading with the anchor the graph points at", () => {
    for (const entry of FAQ) {
      expect(html).toContain(entry.question);
      // `acceptedAnswer.url` is built from this id. If the heading loses it, the
      // graph points at an anchor that resolves to nothing on the page.
      expect(
        html,
        `heading for "${entry.question}" lost its id="${entry.id}"`
      ).toContain(`id="${entry.id}"`);
    }
  });

  it("has a unique anchor", () => {
    const ids = FAQ.map((entry) => entry.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  /**
   * The rule that cost this page one FAQ entry, and the reason it is a test
   * rather than a note.
   *
   * "How is this different from Granola?" was answered by an entry here and, as
   * of 11 August, by a whole section under an `h2` asking the same thing. Two
   * different answers to one question on one page is worse for an answer engine
   * than either alone, so the entry went and the section kept the answer. This
   * fails the moment somebody re-adds a question a section already owns.
   */
  it("never re-asks a question a section heading already asks", () => {
    const headings = Object.values(SECTIONS).map((section) =>
      normalise(section.heading)
    );
    for (const entry of FAQ) {
      expect(
        headings,
        `"${entry.question}" duplicates a section heading`
      ).not.toContain(normalise(entry.question));
    }
  });
});

describe("the FAQPage node", () => {
  it("covers every rendered entry and nothing else", () => {
    expect(faqNode.mainEntity).toHaveLength(FAQ.length);
  });

  it("points every acceptedAnswer at an anchor on this page", () => {
    for (const question of faqNode.mainEntity) {
      expect(question.acceptedAnswer.url).toMatch(PAGE_ANCHOR);
    }
  });
});
