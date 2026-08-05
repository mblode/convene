import { Button } from "@/components/ui/button";
import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";
import { siteConfig } from "@/lib/config";

import { IphoneMock } from "../mocks/iphone-mock";

const DIFFERENCES = [
  {
    body: "iOS will not let an app capture another app’s audio, so the phone records the room and the speakers get split apart afterwards. Put it on the table.",
    title: "Built for the meetings you walk into",
  },
  {
    body: "Type while you listen and your notes go into the summary alongside the transcript. The Mac app has no notes field; this is the one place it exists.",
    title: "A notes field you can actually type in",
  },
  {
    body: "Point it at the same vault as your Mac and the notes meet there. No account, no CloudKit, no sync service: just the folder you already sync.",
    title: "Same vault, both devices",
  },
] as const;

export const Iphone = () => {
  const { testflight } = siteConfig.links;

  return (
    <Section className="border-border/60 border-t" id="iphone">
      <Container>
        <div className="grid items-center gap-12 lg:grid-cols-[minmax(0,1fr)_minmax(0,20rem)] lg:gap-16">
          <div>
            <SectionHeading
              eyebrow="On your iPhone"
              lede="For the meetings that happen in a room rather than a window."
            >
              The other half of your week.
            </SectionHeading>

            <dl className="mt-8 space-y-6">
              {DIFFERENCES.map((item, index) => (
                <Reveal delay={index * 0.08} key={item.title}>
                  <dt className="font-medium tracking-tight">{item.title}</dt>
                  <dd className="mt-1.5 max-w-[58ch] text-muted-foreground leading-relaxed">
                    {item.body}
                  </dd>
                </Reveal>
              ))}
            </dl>

            <Reveal className="mt-8" delay={0.24}>
              {testflight ? (
                <>
                  <Button
                    render={<a href={testflight}>Join the TestFlight beta</a>}
                    size="lg"
                  />
                  <p className="mt-3 text-muted-foreground text-sm">
                    {siteConfig.requirements.ios} · Free · Open the link on your
                    iPhone
                  </p>
                </>
              ) : (
                <div className="rounded-xl bg-card p-5">
                  <p className="font-medium text-sm">Not open to testers yet</p>
                  <p className="mt-1.5 max-w-[58ch] text-muted-foreground text-sm leading-relaxed">
                    Built and working, waiting on Apple’s beta review before the
                    TestFlight link can be public. Build it from source in the
                    meantime; it will show up here the day it opens.
                  </p>
                  <Button
                    className="mt-4"
                    render={
                      <a
                        href={siteConfig.links.github}
                        rel="noopener noreferrer"
                        target="_blank"
                      >
                        Build it from source
                      </a>
                    }
                    size="sm"
                    variant="secondary"
                  />
                </div>
              )}
            </Reveal>
          </div>

          <Reveal delay={0.12}>
            <IphoneMock />
          </Reveal>
        </div>
      </Container>
    </Section>
  );
};
