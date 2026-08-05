"use client";

import { MotionConfig } from "motion/react";
import type { ReactNode } from "react";

/** Motion does not read prefers-reduced-motion on its own: without this every
 * motion.* element keeps animating for someone who asked the OS not to.
 * `"user"` disables transform and layout animation while leaving opacity
 * crossfades, so icon swaps still read as a change rather than a jump. */
export const MotionProvider = ({ children }: { children: ReactNode }) => (
  <MotionConfig reducedMotion="user">{children}</MotionConfig>
);
