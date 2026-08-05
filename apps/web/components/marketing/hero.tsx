import { DownloadButton } from "@/components/shared/download-button";
import { CopyButton } from "@/components/ui/copy-button";
import { Reveal } from "@/components/ui/reveal";
import { Container } from "@/components/ui/section";
import { siteConfig } from "@/lib/config";
import type { Release } from "@/lib/release";

import { MenuBarMock } from "../mocks/menu-bar-mock";

export const Hero = ({ release }: { release: Release }) => (
  <section className="relative overflow-hidden pt-28 pb-16 sm:pt-36 sm:pb-24">
    <div
      aria-hidden="true"
      className="hero-glow pointer-events-none absolute inset-0"
    />

    <Container className="relative">
      <div className="max-w-3xl">
        <Reveal>
          <h1 className="max-w-[19ch] text-balance font-display font-light text-5xl tracking-tight sm:text-6xl sm:tracking-[-0.03em]">
            Your meetings, as Markdown in your own folder.
          </h1>
        </Reveal>

        <Reveal delay={0.08}>
          <p className="mt-6 max-w-[50ch] text-pretty text-lg text-muted-foreground leading-relaxed sm:text-xl">
            Records both sides of the call, transcribes it live, writes the note
            into your Obsidian vault. No bot joins. No Convene server.
          </p>
        </Reveal>

        <Reveal delay={0.16}>
          <div className="mt-9 flex flex-wrap items-center gap-x-4 gap-y-3">
            <DownloadButton href={release.downloadUrl} placement="hero" />
            {release.fileSize ? (
              <span className="text-muted-foreground text-sm tabular-nums">
                {release.fileSize}
              </span>
            ) : null}
          </div>

          <p className="mt-3.5 text-muted-foreground text-sm">
            {release.version} · {siteConfig.requirements.macos} · MIT
            {release.publishedRelative ? ` · ${release.publishedRelative}` : ""}
          </p>

          {/* Homebrew stays small text with a copy affordance, never a second
              button: the page has exactly one primary action. */}
          <div className="mt-5 flex items-center gap-1 text-muted-foreground text-sm">
            <span>Or</span>
            <code className="ml-1 rounded-md bg-secondary px-2 py-1 font-mono text-[0.8125rem] text-foreground">
              {siteConfig.brewCommand}
            </code>
            <CopyButton
              content={siteConfig.brewCommand}
              label="the Homebrew command"
            />
          </div>
        </Reveal>
      </div>

      {/* Capped narrower than the text column: the popover hangs off the right
          of the menu bar, and a full-width frame leaves empty desktop beside it. */}
      <Reveal className="mt-14 sm:mt-20" delay={0.24}>
        <MenuBarMock className="mx-auto max-w-3xl" />
      </Reveal>
    </Container>
  </section>
);
