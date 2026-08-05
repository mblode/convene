import { DownloadButton } from "@/components/shared/download-button";
import { Reveal } from "@/components/ui/reveal";
import { Container, Section } from "@/components/ui/section";
import { siteConfig } from "@/lib/config";
import type { Release } from "@/lib/release";

export const ClosingCta = ({ release }: { release: Release }) => (
  <Section className="border-border/60 border-t">
    <Container>
      <Reveal className="flex flex-col items-center text-center">
        <h2 className="max-w-[22ch] text-balance font-display font-light text-3xl tracking-tight sm:text-4xl">
          Take the notes. Keep the files.
        </h2>
        <p className="mt-4 max-w-[46ch] text-pretty text-muted-foreground">
          Free, MIT licensed, no account. The next meeting can write itself
          down.
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
