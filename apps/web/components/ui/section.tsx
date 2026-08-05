import type { ComponentProps, ReactNode } from "react";

import { cn } from "@/lib/utils";

/** The page's vertical rhythm lives here. Sections are full-bleed and the
 * inner Container is a fixed max-width, so layout splits use viewport
 * breakpoints — a container query here would just measure the viewport under
 * a different, smaller scale (@lg is 32rem, not 64rem) and fire far too early. */
const Section = ({
  className,
  children,
  ...props
}: ComponentProps<"section">) => (
  <section className={cn("scroll-mt-20 py-16 sm:py-24", className)} {...props}>
    {children}
  </section>
);

const Container = ({
  className,
  children,
  ...props
}: ComponentProps<"div">) => (
  <div
    className={cn("mx-auto w-full max-w-5xl px-4 sm:px-6", className)}
    {...props}
  >
    {children}
  </div>
);

interface SectionHeadingProps {
  children: ReactNode;
  className?: string;
  eyebrow?: string;
  lede?: ReactNode;
  align?: "start" | "center";
}

const SectionHeading = ({
  align = "start",
  children,
  className,
  eyebrow,
  lede,
}: SectionHeadingProps) => (
  <div className={cn(align === "center" && "text-center", className)}>
    {eyebrow ? (
      <p className="mb-3 font-medium text-muted-foreground text-sm tracking-wide">
        {eyebrow}
      </p>
    ) : null}
    <h2 className="text-balance font-display font-light text-3xl tracking-tight sm:text-4xl sm:tracking-[-0.02em]">
      {children}
    </h2>
    {lede ? (
      <p
        className={cn(
          "mt-4 max-w-[56ch] text-pretty text-lg text-muted-foreground",
          align === "center" && "mx-auto"
        )}
      >
        {lede}
      </p>
    ) : null}
  </div>
);

export { Container, Section, SectionHeading };
