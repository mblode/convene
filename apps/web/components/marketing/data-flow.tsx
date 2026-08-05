import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";
import { siteConfig } from "@/lib/config";

import { DataFlowDiagram } from "../mocks/data-flow-diagram";

export const DataFlow = () => (
  <Section className="border-border/60 border-t" id="data">
    <Container>
      <SectionHeading
        eyebrow="Where your data goes"
        lede="Most tools here ask you to trust a policy. Here is the whole path, including the part that is not local."
      >
        No badges. Just the actual route.
      </SectionHeading>

      <Reveal className="mt-10">
        <DataFlowDiagram />
      </Reveal>

      <Reveal className="mt-10 grid gap-8 lg:grid-cols-2" delay={0.08}>
        <div>
          <h3 className="font-medium text-lg tracking-tight">What is true</h3>
          <p className="mt-2 text-muted-foreground leading-relaxed">
            There is no Convene server. Your keys live in the Keychain, the
            requests go from your Mac straight to the providers you chose, and
            the note is a file in your folder. We never receive any of it,
            because nothing is addressed to us.
          </p>
        </div>
        <div>
          <h3 className="font-medium text-lg tracking-tight">What is not</h3>
          <p className="mt-2 text-muted-foreground leading-relaxed">
            Convene is not on-device transcription. Audio streams to AssemblyAI,
            and summaries to Anthropic or OpenAI, over keys you create and pay
            for. If no audio may leave the machine, use something that runs a
            model locally.
          </p>
        </div>
      </Reveal>

      <Reveal
        className="mt-8 flex flex-wrap gap-x-6 gap-y-2 text-sm"
        delay={0.16}
      >
        <a
          className="rounded text-link underline decoration-link/30 underline-offset-4 transition-colors hover:decoration-link focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
          href={siteConfig.links.keychainSource}
          rel="noopener noreferrer"
          target="_blank"
        >
          The code that stores your keys
        </a>
        <a
          className="rounded text-link underline decoration-link/30 underline-offset-4 transition-colors hover:decoration-link focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
          href={siteConfig.links.persistenceSource}
          rel="noopener noreferrer"
          target="_blank"
        >
          The code that writes your notes
        </a>
        <a
          className="rounded text-link underline decoration-link/30 underline-offset-4 transition-colors hover:decoration-link focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
          href={siteConfig.links.walSource}
          rel="noopener noreferrer"
          target="_blank"
        >
          The crash log that saves your meeting
        </a>
      </Reveal>
    </Container>
  </Section>
);
