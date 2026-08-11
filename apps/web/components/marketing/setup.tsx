import type { ReactNode } from "react";

import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";
import { siteConfig } from "@/lib/config";
import { SECTIONS } from "@/lib/landing";

interface Step {
  body: ReactNode;
  /** Only where a retired FAQ entry's anchor moved onto the step. "Why does it
   * need screen recording permission?" was answered by an entry listing the
   * same three permissions this step lists, in the same order; the entry went
   * and `#permissions` came here, because it was published as an
   * `acceptedAnswer.url` and every link ever made against it has to land. */
  id?: string;
  title: string;
}

const STEPS: Step[] = [
  {
    body: "Microphone, Calendar, and the screen permission macOS uses for system audio. Audio only, no video. Notifications are optional, and only used to offer recording when a meeting app opens.",
    id: "permissions",
    title: "Grant three permissions",
  },
  {
    body: (
      <>
        Runs on your own{" "}
        <a
          className="rounded text-link underline decoration-link/30 underline-offset-4 transition-colors hover:decoration-link focus-visible:ring-3 focus-visible:ring-ring focus-visible:outline-none"
          href={siteConfig.links.assemblyai}
          rel="noopener noreferrer"
          target="_blank"
        >
          AssemblyAI
        </a>{" "}
        key, so you pay them directly. Paste it once. It goes into your
        Keychain.
      </>
    ),
    title: "Paste an AssemblyAI key",
  },
  {
    body: "If you use Obsidian, pick the vault. The notes show up in it.",
    title: "Choose your notes folder",
  },
];

export const Setup = () => (
  <Section className="border-border/60 border-t" id="setup">
    <Container>
      <div className="grid gap-10 lg:grid-cols-[minmax(0,26rem)_minmax(0,1fr)] lg:gap-16">
        <SectionHeading eyebrow="Setup" lede={SECTIONS.setup.lede}>
          {SECTIONS.setup.heading}
        </SectionHeading>

        <ol className="space-y-7">
          {STEPS.map((step, index) => (
            <Reveal
              as="li"
              className="flex gap-4"
              delay={index * 0.08}
              key={step.title}
            >
              <span
                aria-hidden="true"
                className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-cerulean/10 font-semibold text-link text-sm tabular-nums"
              >
                {index + 1}
              </span>
              <div className="min-w-0 pt-1">
                <h3
                  className="scroll-mt-24 font-medium tracking-tight"
                  id={step.id}
                >
                  {step.title}
                </h3>
                <p className="mt-1.5 text-muted-foreground leading-relaxed">
                  {step.body}
                </p>
              </div>
            </Reveal>
          ))}

          {/* The line that turns "I need three accounts" into "I need one". */}
          <Reveal as="li" className="text-muted-foreground" delay={0.24}>
            Summaries are optional. Without an Anthropic or OpenAI key you still
            get the transcript, your key moments, and the note in your folder.
          </Reveal>
        </ol>
      </div>
    </Container>
  </Section>
);
