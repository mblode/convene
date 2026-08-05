import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";

import { IphoneMock } from "../mocks/iphone-mock";

export const Iphone = () => (
  <Section className="border-border/60 border-t" id="iphone">
    <Container>
      <div className="grid items-center gap-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,20rem)] lg:gap-16">
        <div>
          <SectionHeading
            eyebrow="On your iPhone"
            lede="iOS will not let an app capture another app's audio, so the phone records the room and splits the speakers afterwards. Put it on the table. Point it at the same vault as your Mac and the notes meet there."
          >
            For the meetings in a room.
          </SectionHeading>
        </div>

        <Reveal delay={0.12}>
          <IphoneMock />
        </Reveal>
      </div>
    </Container>
  </Section>
);
