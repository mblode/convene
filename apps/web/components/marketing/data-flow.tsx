import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";
import { siteConfig } from "@/lib/config";

import { DataFlowDiagram } from "../mocks/data-flow-diagram";

export const DataFlow = () => (
  <Section className="border-border/60 border-t" id="data">
    <Container>
      <SectionHeading eyebrow="Where your data goes">
        No badges. Just the actual route.
      </SectionHeading>

      <Reveal className="mt-10">
        <DataFlowDiagram />
      </Reveal>

      <Reveal className="mt-8 max-w-[58ch]" delay={0.08}>
        <p className="text-muted-foreground leading-relaxed">
          Audio does leave your Mac, to providers you pay directly. What never
          happens is a stop at a Convene server, because there is not one.{" "}
          <a
            className="rounded text-link underline decoration-link/30 underline-offset-4 transition-colors hover:decoration-link focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
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
