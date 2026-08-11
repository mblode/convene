import Link from "next/link";

import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";
import { COMPARED_ON, COMPARISON, SECTIONS } from "@/lib/landing";

/**
 * The comparison, as a real `<table>`.
 *
 * A real table rather than a grid of divs, because this is the block most
 * likely to be quoted by something that is not a browser: `<th scope>` is what
 * lets a machine say "Convene: Markdown files in a folder you pick" instead of
 * reading a column of orphaned strings. The `<caption>` carries the checked-on
 * date, which is the difference between a claim and a checked claim.
 *
 * Six rows, not the thirteen on `/granola-alternative`. This is the summary
 * that earns the click, and every cell is copied from that page rather than
 * researched again — one place where a Granola claim is verified, one date on
 * it, no chance of the two disagreeing.
 *
 * The honesty paragraph is not a hedge and should not be softened. It is the
 * answer that used to sit in the FAQ under "How is this different from
 * Granola?", moved here whole when this section took over the question. A
 * comparison with no losing row reads as marketing and gets discounted
 * entirely, including the rows that were true.
 */
export const ComparisonTable = () => (
  <Section className="border-border/60 border-t" id="comparison">
    <Container>
      <Reveal>
        <SectionHeading eyebrow="Against the obvious alternative">
          {SECTIONS.comparison.heading}
        </SectionHeading>

        {/* A labelled landmark with a tab stop: the WCAG-documented pattern for
            a scrollable region, and all three parts are load-bearing. Without
            the tab stop a keyboard user cannot pan the table and simply loses
            the Granola column on a phone. Without the accessible name the focus
            stop is a dead end with nothing announced. */}
        <section
          aria-label="Convene and Granola compared"
          className="-mx-4 mt-8 overflow-x-auto px-4 sm:mx-0 sm:px-0"
          // oxlint-disable-next-line jsx-a11y/no-noninteractive-tabindex -- a scrollable region must be keyboard-reachable, WCAG 2.1 G202. The rule guards a stray tab stop on an anonymous div; this one is named and holds content only panning reaches.
          tabIndex={0}
        >
          <table className="w-full min-w-[34rem] border-collapse text-left text-sm">
            <caption className="pb-4 text-left text-muted-foreground text-sm">
              Checked against Granola&rsquo;s public pricing and product pages
              on {COMPARED_ON}. They ship often, so check before deciding.
            </caption>
            <thead>
              <tr className="border-border border-b">
                {/* The corner cell. Blank on screen because a header for the
                    row-header column is noise, but named for a screen reader,
                    which announces it before every row label. */}
                <td className="py-3 pr-4">
                  <span className="sr-only">Feature</span>
                </td>
                {COMPARISON.columns.map((column) => (
                  <th
                    className="py-3 pr-4 font-medium text-foreground"
                    key={column}
                    scope="col"
                  >
                    {column}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {COMPARISON.rows.map((row) => (
                <tr
                  className="border-border/60 border-b align-top"
                  key={row.label}
                >
                  <th
                    className="py-3 pr-4 font-medium text-foreground"
                    scope="row"
                  >
                    {row.label}
                  </th>
                  {row.values.map((value, index) => (
                    <td
                      className="py-3 pr-4 text-muted-foreground"
                      key={`${row.label}-${COMPARISON.columns[index]}`}
                    >
                      {value}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </section>

        <p className="mt-6 max-w-[65ch] text-pretty text-muted-foreground leading-relaxed">
          {COMPARISON.honesty}
        </p>

        <p className="mt-4 text-sm">
          <Link
            className="rounded text-link underline decoration-link/30 underline-offset-4 transition-colors hover:decoration-link focus-visible:ring-3 focus-visible:ring-ring focus-visible:outline-none"
            href="/granola-alternative"
          >
            The full comparison, thirteen rows and the caveats
          </Link>
        </p>
      </Reveal>
    </Container>
  </Section>
);
