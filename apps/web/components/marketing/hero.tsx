import { DownloadButton } from "@/components/shared/download-button";
import { Reveal } from "@/components/ui/reveal";
import { Container } from "@/components/ui/section";
import type { Release } from "@/lib/release";

import { MenuBarMock } from "../mocks/menu-bar-mock";

export const Hero = ({ release }: { release: Release }) => (
  // Deliberately small top padding: the breadcrumb row above this in
  // `app/page.tsx` already clears the fixed header, so repeating that here
  // would stack two gaps. This is the root page's hero and nothing else's.
  <section className="relative overflow-hidden pt-6 pb-16 sm:pt-8 sm:pb-24">
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

        {/* One action, nothing beside it. Version, requirements and the Homebrew
            command live at the closing CTA and in the FAQ, where someone is
            deciding rather than reading. */}
        <Reveal className="mt-9" delay={0.16}>
          <DownloadButton href={release.downloadUrl} placement="hero" />
        </Reveal>
      </div>

      {/* Left edge aligns with the headline rather than centring: a centred
          frame under left-aligned text reads as a misalignment. Capped at 2xl
          so the popover fills a fair share of the frame instead of floating in
          empty desktop. */}
      <Reveal className="mt-12 sm:mt-16" delay={0.24}>
        <MenuBarMock className="max-w-2xl" />
      </Reveal>
    </Container>
  </section>
);
