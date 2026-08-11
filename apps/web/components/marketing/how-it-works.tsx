import { Container, Section, SectionHeading } from "@/components/ui/section";
import { SECTIONS } from "@/lib/landing";

import { HandoffMock } from "../mocks/handoff-mock";
import { TranscriptMock } from "../mocks/transcript-mock";

/**
 * Three steps, stacked, at every width.
 *
 * This used to render twice: a `role="tablist"` panel behind `hidden lg:block`
 * and the same three steps stacked behind `lg:hidden`. Both copies shipped in
 * the HTML and one was always invisible, which is the expensive half. The
 * cheaper half is that the tablist did not work — all three tabs were
 * `tabIndex=0` and no arrow-key handler was ever wired up, so a keyboard user
 * got three tab stops and the arrow behaviour the role promises did not exist.
 * Two of the three `aria-controls` targets pointed at panels that were not in
 * the document either, because only the active panel rendered.
 *
 * Deleting the tabs also deleted the `useState` that made this a client
 * component, so the section is now server-rendered markup with two client mocks
 * inside it.
 */
const STEPS: {
  body: string;
  id: string;
  /**
   * Absent on the first step, and that is the point. It used to be
   * `MenuBarMock` — the same component the hero renders, with a byte-identical
   * `figcaption`, about 3,100px further down the same page. A reader who scrolls
   * that far is shown the picture they arrived on, and the second copy costs a
   * duplicate image, a second animation clock and another hydrated subtree for a
   * step whose copy stands on its own.
   */
  mock?: typeof TranscriptMock;
  tab: string;
  title: string;
}[] = [
  {
    body: "Every calendar you already have in Calendar.app, in the menu bar. Click an event to open the call and start recording.",
    id: "before",
    tab: "Before",
    title: "Your day, one click away",
  },
  {
    body: "Your mic and your Mac's system audio run as two separate streams, so your side and theirs are never guessed at. Hit ⌥⇧K to flag a moment.",
    id: "during",
    mock: TranscriptMock,
    tab: "During",
    title: "Both sides, transcribed live",
  },
  {
    /* Carries the fact the retired handoff section's lede carried, because the
     * mock beside it is that section's mock. */
    body: "Stop, and the file is on disk. The summary rewrites the note in place a moment later, built from the transcript: the line you spoke at 00:44 becomes the action item and links back to that second.",
    id: "after",
    /* `HandoffMock`, not `MarkdownNoteMock`. It shows the saved note *and* the
     * transcript line it came from, in fewer rendered words than the note mock
     * spent rendering the note alone — and the note mock's third pane was a
     * second copy of the transcript one step above it. */
    mock: HandoffMock,
    tab: "After",
    title: "A Markdown file, straight away",
  },
];

export const HowItWorks = () => (
  <Section className="border-border/60 border-t" id="how-it-works">
    <Container>
      <SectionHeading eyebrow="How it works" lede={SECTIONS.howItWorks.lede}>
        {SECTIONS.howItWorks.heading}
      </SectionHeading>

      <ol className="mt-10 space-y-14">
        {STEPS.map((item) => {
          const Mock = item.mock;
          return (
            <li key={item.id}>
              <p className="font-medium text-muted-foreground text-sm">
                {item.tab}
              </p>
              <h3 className="mt-1.5 font-medium text-xl tracking-tight">
                {item.title}
              </h3>
              <p className="mt-3 max-w-[60ch] text-muted-foreground leading-relaxed">
                {item.body}
              </p>
              {Mock ? <Mock className="mt-6" /> : null}
            </li>
          );
        })}
      </ol>
    </Container>
  </Section>
);
