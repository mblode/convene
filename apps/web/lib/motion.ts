/** House motion preset: a 4px blur lifting 8px into place over 0.65s.
 * The easing is the same curve used across blode.co — keep them in sync. */
export const blurUp = {
  animate: { filter: "blur(0px)", opacity: 1, y: 0 },
  initial: { filter: "blur(4px)", opacity: 0, y: 8 },
  transition: {
    duration: 0.65,
    ease: [0.25, 1, 0.5, 1] as const,
  },
} as const;

/** Stagger helper for index-based children: `blurUpAt(i)` spreads a grid. */
export const blurUpAt = (index: number, step = 0.08) => ({
  ...blurUp,
  transition: { ...blurUp.transition, delay: index * step },
});
