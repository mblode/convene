import {
  CalendarDaysIcon,
  FileTextIcon,
  KeyboardIcon,
  MicrophoneIcon,
  ShieldKeyholeIcon,
  SparkleIcon,
} from "blode-icons-react";
import type { ReactNode } from "react";

import { Kbd } from "@/components/ui/kbd";
import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";

interface Feature {
  body: string;
  chip?: ReactNode;
  icon: typeof MicrophoneIcon;
  title: string;
}

/** Every line here maps to something in the Swift source. Nothing aspirational,
 * nothing rounded up. Six, not nine: the cut ones were true but nobody picks a
 * meeting recorder on echo suppression. */
const FEATURES: Feature[] = [
  {
    body: "Your mic and your Mac's system audio run as two transcription streams, and several people on the far end get split apart by speaker.",
    chip: <span className="font-mono text-[11px]">2 streams</span>,
    icon: MicrophoneIcon,
    title: "Both sides, captured separately",
  },
  {
    body: "Every calendar you have in Calendar.app, with a countdown to the next call. Click an event to join it and start recording.",
    icon: CalendarDaysIcon,
    title: "Today's schedule in the menu bar",
  },
  {
    body: "Flag the thing that just mattered without leaving the call. It lands in an index at the top of the note and inline at the right second.",
    chip: <Kbd>⌥⇧K</Kbd>,
    icon: KeyboardIcon,
    title: "Key moments, from anywhere",
  },
  {
    body: "Every confirmed segment is written to an append-only log as it goes. Crash mid-meeting and Convene rebuilds the note on next launch.",
    icon: ShieldKeyholeIcon,
    title: "A crash costs you two seconds",
  },
  {
    body: "The summary can only cite timestamps that exist, and each one is a working wikilink into the transcript. No invented decisions, no invented owners.",
    icon: SparkleIcon,
    title: "Summaries that cite the tape",
  },
  {
    body: "Frontmatter, a TL;DR, decisions, an action-item checklist, and the transcript under timestamped headings. Plain text, forever readable.",
    icon: FileTextIcon,
    title: "One tidy Markdown file",
  },
];

export const Features = () => (
  <Section className="border-border/60 border-t" id="features">
    <Container>
      <SectionHeading eyebrow="Features">
        Small app. Careful about the details.
      </SectionHeading>

      <ul className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {FEATURES.map((feature, index) => (
          <Reveal
            as="li"
            className="flex flex-col rounded-xl bg-card p-5"
            delay={(index % 3) * 0.06}
            key={feature.title}
          >
            {/* Fixed height so a card with a chip and one without still put
                their titles on the same baseline across a row. */}
            <div className="flex h-5 items-center justify-between gap-3">
              <feature.icon
                aria-hidden="true"
                className="size-5 text-cerulean"
              />
              {feature.chip ? (
                <span className="text-muted-foreground">{feature.chip}</span>
              ) : null}
            </div>
            <h3 className="mt-4 font-medium tracking-tight">{feature.title}</h3>
            <p className="mt-1.5 text-muted-foreground text-sm leading-relaxed">
              {feature.body}
            </p>
          </Reveal>
        ))}
      </ul>
    </Container>
  </Section>
);
