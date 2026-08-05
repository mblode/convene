"use client";

import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Container, Section, SectionHeading } from "@/components/ui/section";
import { FAQ } from "@/lib/faq";

export const FaqSection = () => (
  <Section className="border-border/60 border-t" id="faq">
    <Container>
      <div className="grid gap-10 lg:grid-cols-[minmax(0,22rem)_minmax(0,1fr)] lg:gap-16">
        <SectionHeading
          className="lg:sticky lg:top-24 lg:self-start"
          eyebrow="Questions"
          lede="Including the awkward ones. If one reads like a dodge, open an issue."
        >
          Answers, not hedges.
        </SectionHeading>

        <Accordion className="w-full" collapsible type="single">
          {FAQ.map((item) => (
            <AccordionItem key={item.question} value={item.question}>
              <AccordionTrigger>{item.question}</AccordionTrigger>
              <AccordionContent>{item.answer}</AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </Container>
  </Section>
);
