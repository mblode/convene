import Link from "next/link";
import type { ReactNode } from "react";

import { SiteFooter } from "@/components/shared/site-footer";
import { SiteHeader } from "@/components/shared/site-header";
import { Container, Section } from "@/components/ui/section";
import { getLatestRelease } from "@/lib/release";

/*
 * The shell the privacy and support pages share: a back link, a title, and a column of
 * sections. It exists because there are two of them and they are the same page twice; if a
 * third long-form page ever wants a different shape, give it its own rather than adding a
 * variant here.
 *
 * The marketing pages use `components/shared/article.tsx` instead: same idea on a wider
 * measure, plus the dateline a comparison page needs.
 */

/** Link styling, as a class string. Inline `<a>`s are written by hand so the surrounding
 *  sentence stays readable in the source. */
export const LINK =
  "rounded text-link underline decoration-border underline-offset-4 transition-colors hover:decoration-current focus-visible:ring-3 focus-visible:ring-ring focus-visible:outline-none";

export const DocPage = async ({
  children,
  intro,
  meta,
  title,
}: {
  children: ReactNode;
  intro: string;
  /** Optional line under the intro, e.g. the last-updated date. */
  meta?: string;
  title: string;
}) => {
  const { downloadUrl } = await getLatestRelease();

  return (
    <div className="flex min-h-dvh flex-col">
      <SiteHeader downloadUrl={downloadUrl} />

      <main className="flex-1 pt-14" id="main">
        <Section className="pb-0">
          <Container className="max-w-2xl">
            <Link
              className="rounded text-muted-foreground text-sm transition-colors hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring focus-visible:outline-none"
              href="/"
            >
              ← Convene
            </Link>

            <h1 className="mt-6 text-balance font-display font-light text-4xl tracking-tight sm:text-5xl sm:tracking-[-0.02em]">
              {title}
            </h1>

            <p className="mt-5 text-pretty text-lg text-muted-foreground leading-relaxed">
              {intro}
            </p>

            {meta ? (
              <p className="mt-4 text-muted-foreground text-sm">{meta}</p>
            ) : null}
          </Container>
        </Section>

        <Section className="pt-10">
          <Container className="max-w-2xl">
            <div className="flex flex-col gap-12">{children}</div>
          </Container>
        </Section>
      </main>

      <SiteFooter />
    </div>
  );
};

export const DocSection = ({
  children,
  title,
}: {
  children: ReactNode;
  title: string;
}) => (
  <section className="border-border/60 border-t pt-8">
    <h2 className="font-display font-light text-2xl tracking-tight">{title}</h2>
    <div className="mt-4 flex flex-col gap-4 text-muted-foreground leading-relaxed">
      {children}
    </div>
  </section>
);

/** A sub-heading inside a section, for the named states the support page walks through. */
export const DocHeading = ({ children }: { children: ReactNode }) => (
  <h3 className="mt-2 font-medium text-foreground">{children}</h3>
);

export const DocList = ({ children }: { children: ReactNode }) => (
  <ul className="flex flex-col gap-3">{children}</ul>
);

export const DocItem = ({ children }: { children: ReactNode }) => (
  <li className="flex items-start gap-3">
    <span
      aria-hidden="true"
      className="mt-2.5 size-1 shrink-0 rounded-full bg-cerulean"
    />
    <span>{children}</span>
  </li>
);

/** Endpoints and file paths, sized down so they sit on the body baseline. */
export const Code = ({ children }: { children: ReactNode }) => (
  <code className="font-mono text-[0.9em] text-foreground">{children}</code>
);
