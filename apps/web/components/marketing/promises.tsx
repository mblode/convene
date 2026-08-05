import { FolderOpenIcon, RobotIcon, VideoOnIcon } from "blode-icons-react";

import { Reveal } from "@/components/ui/reveal";
import { Container, Section } from "@/components/ui/section";

const PROMISES = [
  {
    body: "It captures the audio your Mac is already playing. Nothing joins the call, nothing shows up in the participant list.",
    icon: RobotIcon,
    title: "No bot joins your meeting",
  },
  {
    body: "A Markdown file in a folder you picked, written the moment you stop. Nothing to export.",
    icon: FolderOpenIcon,
    title: "Your notes are files you own",
  },
  {
    body: "Zoom, Meet, Teams, Webex, BlueJeans, anything that makes sound. There is nothing to integrate.",
    icon: VideoOnIcon,
    title: "Works with every meeting app",
  },
] as const;

export const Promises = () => (
  <Section>
    <Container>
      <ul className="grid gap-8 lg:grid-cols-3 lg:gap-10">
        {PROMISES.map((promise, index) => (
          <Reveal as="li" delay={index * 0.08} key={promise.title}>
            <promise.icon aria-hidden="true" className="size-5 text-cerulean" />
            <h3 className="mt-4 font-medium text-lg tracking-tight">
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
