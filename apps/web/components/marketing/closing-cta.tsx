import { DownloadButton } from "@/components/shared/download-button";
import { Reveal } from "@/components/ui/reveal";
import { Container, Section } from "@/components/ui/section";
import { siteConfig } from "@/lib/config";
import { SECTIONS } from "@/lib/landing";
import type { Release } from "@/lib/release";

export const ClosingCta = ({ release }: { release: Release }) => (
  <Section className="border-border/60 border-t">
    <Container>
      <Reveal className="flex flex-col items-center text-center">
        {/* "Take the notes. Keep the files." was the h2 and is now the opening
            line of the paragraph, which is a demotion in markup only. The
            heading above it is the question somebody types; the line under it is
            the one they remember. Neither had to lose for the other to win. */}
        <h2 className="max-w-[26ch] text-balance font-display font-light text-3xl tracking-tight sm:text-4xl">
          {SECTIONS.closing.heading}
        </h2>
        <p className="mt-4 max-w-[52ch] text-pretty text-muted-foreground">
          {SECTIONS.closing.lede}
        </p>
        <DownloadButton
          className="mt-8"
          href={release.downloadUrl}
          placement="closing"
        />
        <p className="mt-3.5 text-muted-foreground text-sm">
          {release.version} · {siteConfig.requirements.macos}
          {release.fileSize ? ` · ${release.fileSize}` : ""}
        </p>
      </Reveal>
    </Container>
  </Section>
);
