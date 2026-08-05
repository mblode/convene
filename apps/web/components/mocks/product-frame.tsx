import type { ComponentProps, ReactNode } from "react";

import { cn } from "@/lib/utils";

interface ProductFrameProps extends Omit<ComponentProps<"figure">, "children"> {
  children: ReactNode;
  /** Read aloud in place of the mock, which is decorative to a screen reader.
   * Every mock must supply one: the information in the pixels has to exist as
   * text too, or the page says less to some visitors than to others. */
  description: string;
  caption?: ReactNode;
}

/** The single frame every product mock sits in, so a real screenshot can
 * replace the markup later without touching surrounding layout. */
export const ProductFrame = ({
  caption,
  children,
  className,
  description,
  ...props
}: ProductFrameProps) => (
  <figure className={cn("group/frame", className)} {...props}>
    <div
      aria-hidden="true"
      className="chrome-surface overflow-hidden rounded-2xl bg-chrome shadow-lifted ring-1 ring-foreground/10"
    >
      {children}
    </div>
    <figcaption className="sr-only">{description}</figcaption>
    {caption ? (
      <p
        className="mt-4 text-center text-muted-foreground text-sm"
        aria-hidden="true"
      >
        {caption}
      </p>
    ) : null}
  </figure>
);
