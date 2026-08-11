import { Container, Section, SectionHeading } from "@/components/ui/section";
import { FAQ } from "@/lib/faq";
import { SECTIONS } from "@/lib/landing";

/**
 * The FAQ, as plain headings and paragraphs.
 *
 * This replaced an `Accordion`, and the obvious reading of why is wrong, so it
 * is worth writing down. It was **not** a crawler fix. `components/ui/accordion.tsx`
 * passes `keepMounted` and `hidden={false}` to the panel, so every answer was
 * already in the server HTML whether or not its item was open — a reader with
 * JS disabled got the whole FAQ, and so did every crawler. Nothing was hidden
 * from a machine and nothing about the structured data was wrong.
 *
 * What was actually wrong is narrower and still real:
 *
 * - a collapsed panel sits at `opacity-0` while remaining in the document, so
 *   its text stayed in the tab order and in find-in-page while being invisible.
 *   That is a worse failure than being absent, because focus can land somewhere
 *   the user cannot see;
 * - an accordion trigger is a `<button>`, not a heading, so fourteen questions
 *   produced no document outline and a screen-reader user had nothing to jump
 *   between;
 * - the page it was saving room on no longer exists. Collapsing bought vertical
 *   space back when the FAQ was most of the page. It is now one section of ten.
 *
 * The `id` on each `<h3>` is load-bearing, not decoration: `faqPageSchema()`
 * publishes it as `acceptedAnswer.url`, so deleting it points the graph at an
 * anchor that resolves to nothing. `scroll-mt-24` is the other half of that
 * promise — the header is fixed, so without it the heading a published anchor
 * lands on is scrolled underneath the header and the reader sees the answer
 * with no question above it.
 *
 * `h3`, not `h2`, because the section has a heading of its own above it.
 */
export const FaqSection = () => (
  <Section className="border-border/60 border-t" id="faq">
    <Container>
      <div className="grid gap-10 lg:grid-cols-[minmax(0,22rem)_minmax(0,1fr)] lg:gap-16">
        <SectionHeading
          className="lg:sticky lg:top-24 lg:self-start"
          eyebrow="Questions"
          lede={SECTIONS.faq.lede}
        >
          {SECTIONS.faq.heading}
        </SectionHeading>

        <dl className="space-y-8">
          {FAQ.map((item) => (
            <div key={item.id}>
              <dt>
                <h3
                  className="max-w-[48ch] scroll-mt-24 text-pretty font-medium text-lg tracking-tight"
                  id={item.id}
                >
                  {item.question}
                </h3>
              </dt>
              <dd className="mt-2 max-w-[68ch] text-pretty text-[0.9375rem] text-muted-foreground leading-relaxed">
                {item.answer}
              </dd>
            </div>
          ))}
        </dl>
      </div>
    </Container>
  </Section>
);
