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

      <Reveal className="mt-10 max-w-[62ch]" delay={0.08}>
        <p className="text-muted-foreground leading-relaxed">
          Convene is not on-device transcription: audio streams to AssemblyAI,
          and summaries to Anthropic or OpenAI, over keys you create and pay
          for. What is true is that there is no Convene server in the middle. We
          never receive any of it, because nothing is addressed to us.
        </p>
        <a
          className="mt-4 inline-block rounded text-link text-sm underline decoration-link/30 underline-offset-4 transition-colors hover:decoration-link focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
          href={siteConfig.links.keychainSource}
          rel="noopener noreferrer"
          target="_blank"
        >
          Read the code that stores your keys
        </a>
      </Reveal>
    </Container>
  </Section>
);
