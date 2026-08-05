"use client";

import { useState } from "react";

import { Container, Section, SectionHeading } from "@/components/ui/section";
import { cn } from "@/lib/utils";

import { MarkdownNoteMock } from "../mocks/markdown-note-mock";
import { MenuBarMock } from "../mocks/menu-bar-mock";
import { TranscriptMock } from "../mocks/transcript-mock";

const STEPS = [
  {
    body: "Every calendar you already have in Calendar.app, in the menu bar. Click an event to open the call and start recording at once.",
    id: "before",
    mock: MenuBarMock,
    tab: "Before",
    title: "Your day, one click away",
  },
  {
    body: "Your mic and your Mac's system audio run as two separate streams, so your side and theirs are never guessed at. Hit ⌥⇧K to flag a moment without leaving the call.",
    id: "during",
    mock: TranscriptMock,
    tab: "During",
    title: "Both sides, transcribed live",
  },
  {
    body: "Stop, and the file is on disk. The summary lands a moment later and rewrites the note in place, so you never wait on a model.",
    id: "after",
    mock: MarkdownNoteMock,
    tab: "After",
    title: "A Markdown file, straight away",
  },
] as const;

export const HowItWorks = () => {
  const [active, setActive] = useState(0);
  const step = STEPS[active];
  const ActiveMock = step.mock;

  return (
    <Section className="border-border/60 border-t" id="how-it-works">
      <Container>
        <SectionHeading eyebrow="How it works">
          From calendar to vault, without a detour.
        </SectionHeading>

        {/* Desktop: tabs. The mock is the payload, so it gets the room. */}
        <div className="mt-10 hidden lg:block">
          <div
            aria-label="Stages of a meeting"
            className="flex gap-1"
            role="tablist"
          >
            {STEPS.map((item, index) => (
              <button
                aria-controls={`panel-${item.id}`}
                aria-selected={index === active}
                className={cn(
                  "rounded-lg px-3.5 py-2 font-medium text-sm transition-colors focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none",
                  index === active
                    ? "bg-primary text-primary-foreground"
                    : "text-muted-foreground hover:bg-secondary hover:text-foreground"
                )}
                id={`tab-${item.id}`}
                key={item.id}
                onClick={() => setActive(index)}
                role="tab"
                type="button"
              >
                {item.tab}
              </button>
            ))}
          </div>

          <div
            aria-labelledby={`tab-${step.id}`}
            className="mt-8 grid grid-cols-[minmax(0,22rem)_minmax(0,1fr)] items-start gap-10"
            id={`panel-${step.id}`}
            role="tabpanel"
          >
            <div>
              <h3 className="font-medium text-xl tracking-tight">
                {step.title}
              </h3>
              <p className="mt-3 text-muted-foreground leading-relaxed">
                {step.body}
              </p>
            </div>
            {/* Keyed so switching tabs remounts the mock and restarts its loop. */}
            <ActiveMock key={step.id} />
          </div>
        </div>

        {/* Mobile: stacked. Tabs hide content behind a control on the width
            where scrolling is cheapest. */}
        <div className="mt-10 space-y-14 lg:hidden">
          {STEPS.map((item) => {
            const Mock = item.mock;
            return (
              <div key={item.id}>
                <p className="font-medium text-muted-foreground text-sm">
                  {item.tab}
                </p>
                <h3 className="mt-1.5 font-medium text-xl tracking-tight">
                  {item.title}
                </h3>
                <p className="mt-3 text-muted-foreground leading-relaxed">
                  {item.body}
                </p>
                <Mock className="mt-6" />
              </div>
            );
          })}
        </div>
      </Container>
    </Section>
  );
};
