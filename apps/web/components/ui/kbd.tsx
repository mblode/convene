import type { ComponentProps } from "react";

import { cn } from "@/lib/utils";

/** Renders a shortcut as its literal glyphs (⌥⇧R), the way macOS menus do.
 * Convene's hotkeys are all modifier chords, so a glyph string beats an
 * icon-per-key: it stays one token and copies as real text. */
const Kbd = ({ className, children, ...props }: ComponentProps<"kbd">) => (
  <kbd
    className={cn(
      "pointer-events-none inline-flex h-5 w-fit min-w-5 select-none items-center justify-center gap-1 rounded-sm bg-muted px-1.5 font-medium font-sans text-muted-foreground text-xs ring-1 ring-border ring-inset",
      className
    )}
    data-slot="kbd"
    {...props}
  >
    {children}
  </kbd>
);

const KbdGroup = ({ className, ...props }: ComponentProps<"kbd">) => (
  <kbd
    className={cn("inline-flex items-center gap-1", className)}
    data-slot="kbd-group"
    {...props}
  />
);

export { Kbd, KbdGroup };
