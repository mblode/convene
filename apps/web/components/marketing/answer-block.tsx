import { Container, Section } from "@/components/ui/section";
import { ANSWER_NOTE, ANSWER_QUESTION, ANSWER_TEXT } from "@/lib/landing";

/**
 * The liftable answer, directly under the fold.
 *
 * An answer engine asked "what is Convene" will quote one paragraph or none.
 * This is that paragraph, and it is written to survive being lifted with
 * nothing around it: no pronoun pointing back at the h1, no "the app", no
 * dependency on the sentence before it.
 *
 * The `h2` is the literal question, and that is the split this page makes — the
 * h1 is a claim a person wants to read ("Your meetings, as Markdown in your own
 * folder."), the h2 is the query a machine matched, and the paragraph answers it
 * once for both of them. Making the h1 itself the question would have served the
 * machine and cost the reader the best line on the site.
 *
 * Deliberately not wrapped in `Reveal`: it sits in the first viewport on a tall
 * desktop window, and content that fades in is content that is briefly absent —
 * on a page whose LCP element is already text, that is the wrong trade.
 */
export const AnswerBlock = () => (
  <Section className="border-border/60 border-y bg-card/40 py-12 sm:py-16">
    <Container>
      <h2 className="max-w-[40ch] text-balance font-display font-light text-3xl tracking-tight sm:text-4xl">
        {ANSWER_QUESTION}
      </h2>
      <p className="mt-5 max-w-[60ch] text-pretty text-lg text-muted-foreground leading-relaxed">
        {ANSWER_TEXT}
      </p>
      <p className="mt-4 text-muted-foreground text-sm">{ANSWER_NOTE}</p>
    </Container>
  </Section>
);
