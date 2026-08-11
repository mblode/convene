import { FolderOpenIcon, RobotIcon, VideoOnIcon } from "blode-icons-react";

import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";
import { SECTIONS } from "@/lib/landing";

/** Two of these three carry an `id`, and it is not decoration. "Does a bot join
 * my meeting?" and "Does it work with Zoom, Google Meet and Teams?" were FAQ
 * entries restating cards that already said it in fewer words, so the entries
 * went and their published `acceptedAnswer.url` anchors moved onto the cards
 * that now own the claim. The middle card was never asked twice, so it has
 * nothing to inherit. */
const PROMISES: {
  body: string;
  icon: typeof RobotIcon;
  id?: string;
  title: string;
}[] = [
  {
    body: "It captures the audio your Mac is already playing. Nothing joins the call and nothing shows up in the participant list. The other people see what they would see if you were taking notes by hand.",
    icon: RobotIcon,
    id: "bot",
    title: "No bot joins your meeting",
  },
  {
    body: "A Markdown file in a folder you picked, written the moment you stop. Nothing to export.",
    icon: FolderOpenIcon,
    title: "Your notes are files you own",
  },
  {
    body: "Zoom, Google Meet, Teams, Webex, anything that makes sound. There is nothing to integrate.",
    icon: VideoOnIcon,
    id: "meeting-apps",
    title: "Works with every meeting app",
  },
];

/** The three cards used to sit under nothing at all. That was the page's
 * `heading-order` failure in the 2026-08-11 Lighthouse run — `ul > li > h3`
 * with no `h2` anywhere above it — and it is why this page scored 95 on
 * accessibility while the other three scored 96. The heading is not decoration
 * added to satisfy an audit; a list of three claims with no sentence saying what
 * they have in common was the actual defect, and the outline was the symptom. */
export const Promises = () => (
  <Section>
    <Container>
      <SectionHeading eyebrow="What you get" lede={SECTIONS.promises.lede}>
        {SECTIONS.promises.heading}
      </SectionHeading>

      <ul className="mt-10 grid gap-8 lg:grid-cols-3 lg:gap-10">
        {PROMISES.map((promise, index) => (
          <Reveal as="li" delay={index * 0.08} key={promise.title}>
            <promise.icon aria-hidden="true" className="size-5 text-cerulean" />
            <h3
              className="mt-4 scroll-mt-24 font-medium text-lg tracking-tight"
              id={promise.id}
            >
              {promise.title}
            </h3>
            <p className="mt-2 text-muted-foreground leading-relaxed">
              {promise.body}
            </p>
          </Reveal>
        ))}
      </ul>
    </Container>
  </Section>
);
