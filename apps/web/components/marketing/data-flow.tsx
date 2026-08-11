import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";
import { siteConfig } from "@/lib/config";
import { SECTIONS } from "@/lib/landing";

/**
 * `id="privacy"`, not `id="data"`, and the rename is the load-bearing part.
 *
 * "Is it private? Does my audio leave my Mac?" used to be an FAQ entry with the
 * most exact answer on the site, sitting a screen below this section, whose
 * `h2` asks the same question and whose paragraph gave the two-sentence version.
 * The long answer moved up here and the entry went. `#privacy` was published as
 * an `acceptedAnswer.url`, so it comes with it; `#data` was an in-page anchor
 * nothing ever linked to, in schema or in navigation.
 *
 * There is no diagram here any more either. It was four equally weighted cards
 * named by party rather than by step, with no ordering cue, sold as "the actual
 * route" while not drawing a route. The paragraph below states the same thing in
 * one sentence and links the code, which is the version a sceptical reader can
 * act on. Deleting it also removed two of the seven separate places this page
 * claimed there is no Convene server, and its `sr-only` description said nothing
 * the paragraph does not: capture stays local, AssemblyAI and the summary
 * providers run on your own keys, no step routes through us.
 */
export const DataFlow = () => (
  <Section className="border-border/60 border-t" id="privacy">
    <Container>
      <SectionHeading
        eyebrow="Where your data goes"
        lede={SECTIONS.dataFlow.lede}
      >
        {SECTIONS.dataFlow.heading}
      </SectionHeading>

      <Reveal className="mt-8 max-w-[58ch]">
        <p className="text-muted-foreground leading-relaxed">
          Capture, the crash log and the finished note stay on your Mac.
          Transcription does not: audio streams to AssemblyAI over your own key,
          and if you turn on summaries the transcript goes to Anthropic or
          OpenAI over your own key. You pay those providers directly, and there
          is no Convene server in between, so we never receive your audio,
          transcript or notes: there is nowhere for them to arrive. If you need
          transcription that never leaves the machine, Convene is not the right
          tool.{" "}
          <a
            className="rounded text-link underline decoration-link/30 underline-offset-4 transition-colors hover:decoration-link focus-visible:ring-3 focus-visible:ring-ring focus-visible:outline-none"
            href={siteConfig.links.keychainSource}
            rel="noopener noreferrer"
            target="_blank"
          >
            Read the code
          </a>
          .
        </p>
      </Reveal>
    </Container>
  </Section>
);
