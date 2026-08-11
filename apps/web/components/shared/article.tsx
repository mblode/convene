import Link from "next/link";
import type { ReactNode } from "react";

import { Container, Section } from "@/components/ui/section";
import { cn } from "@/lib/utils";

/** Shared link treatment for body copy on the long-form pages. */
export const LINK =
  "rounded text-link underline decoration-border underline-offset-4 transition-colors hover:decoration-current focus-visible:ring-3 focus-visible:ring-ring focus-visible:outline-none";

export const Prose = ({
  children,
  id,
  title,
}: {
  children: ReactNode;
  id?: string;
  title: string;
}) => (
  <section className="mt-14 scroll-mt-20 first:mt-0" id={id}>
    <h2 className="font-display font-light text-2xl tracking-tight">{title}</h2>
    <div className="mt-4 space-y-4 text-muted-foreground leading-relaxed">
      {children}
    </div>
  </section>
);

export const Bullets = ({ children }: { children: ReactNode }) => (
  <ul className="space-y-3">{children}</ul>
);

export const Bullet = ({ children }: { children: ReactNode }) => (
  <li className="flex gap-3">
    <span
      aria-hidden="true"
      className="mt-2.5 size-1 shrink-0 rounded-full bg-cerulean"
    />
    <span>{children}</span>
  </li>
);

export const Lead = ({ children }: { children: ReactNode }) => (
  <strong className="font-medium text-foreground">{children}</strong>
);

/**
 * The FAQ on a long-form page, as plain headings and paragraphs.
 *
 * This replaced an `Accordion` on both SEO pages, and it was **not** a crawler
 * fix — `components/ui/accordion.tsx` passes `keepMounted` and `hidden={false}`,
 * so every answer was already in the server HTML whether or not its item was
 * open. What was wrong: a collapsed panel sits at `opacity-0` while staying in
 * the document, so its text remained in the tab order and in find-in-page while
 * being invisible, and an accordion trigger is a `<button>` rather than a
 * heading, so the questions produced no document outline.
 *
 * The `id` on each `<h3>` is published as `acceptedAnswer.url` by
 * `articlePageSchema()`. Deleting it points the graph at an anchor that resolves
 * to nothing.
 *
 * `h3`, not `h2`, because `Prose` renders the section's own `h2` above this.
 */
export const FaqList = ({
  items,
}: {
  items: readonly { answer: string; id: string; question: string }[];
}) => (
  <dl className="space-y-8">
    {items.map((item) => (
      <div key={item.id}>
        <dt>
          <h3
            className="max-w-[48ch] scroll-mt-20 text-pretty font-medium text-foreground text-lg tracking-tight"
            id={item.id}
          >
            {item.question}
          </h3>
        </dt>
        <dd className="mt-2 max-w-[68ch] text-pretty leading-relaxed">
          {item.answer}
        </dd>
      </div>
    ))}
  </dl>
);

/** The masthead every long-form page opens with: a way back, the title, a
 * lede, and an optional dated line — comparison claims go stale, so the date
 * is part of the argument rather than decoration. */
export const ArticleHeader = ({
  dateline,
  lede,
  title,
  width = "max-w-2xl",
}: {
  dateline?: string;
  lede: ReactNode;
  title: ReactNode;
  width?: string;
}) => (
  <Section className="pb-0">
    <Container className={width}>
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
        {lede}
      </p>

      {dateline ? (
        <p className="mt-4 text-muted-foreground text-sm">{dateline}</p>
      ) : null}
    </Container>
  </Section>
);

export const ArticleBody = ({
  children,
  className,
  width = "max-w-2xl",
}: {
  children: ReactNode;
  className?: string;
  width?: string;
}) => (
  <Section className={cn("pt-10", className)}>
    <Container className={width}>{children}</Container>
  </Section>
);
