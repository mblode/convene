"use client";
"use no memo";

import { cn } from "@/lib/utils";

import { ProductFrame } from "./product-frame";
import { useMockClock } from "./use-mock-clock";

/**
 * The handoff: one line of transcript becoming one line of the note.
 *
 * Every other mock on this page shows one half of the product. The transcript
 * mock proves Convene hears both sides; the note mock proves a Markdown file
 * lands on disk. Between them sits the step the page has been *asserting* —
 * that the second is derived from the first — and a reader was being asked to
 * take it on trust. This is that step, shown once.
 *
 * At `00:44` you say "Then let's ship it. Sarah, can you draft the release
 * note?" The transcript line lights, one beat passes, and the matching action
 * item writes itself into the note. Both halves are the same meeting every
 * other mock on the site uses, so the correspondence is checkable against them.
 *
 * **One highlight, one arrival, and deliberately no connector line and no
 * arrow.** A line drawn between the two panes is the reflex here and it is
 * wrong twice over: it draws the claim instead of demonstrating it, and it
 * needs absolute positioning that breaks the moment the panes stack on a phone.
 * Timing carries the causation — the note line cannot arrive before the
 * transcript line lights, so the order *is* the argument.
 *
 * LCP and CLS discipline, all of it load-bearing:
 * - it sits below the fold, so it is never the LCP element;
 * - `initialStep: FINAL` server-renders the *finished* frame, so a reader with
 *   JS off gets the proof rather than an empty box, and the loop rewinds after
 *   mount;
 * - both panes reserve their tallest state with `min-h`, so nothing grows into
 *   the page and no arriving line can shift what is under it;
 * - `useMockClock` gates on IntersectionObserver, so it does not tick
 *   off-screen, and parks on the finished frame under reduced motion.
 */

/** The transcript, trimmed to the four lines the handoff needs. Longer and the
 * two panes stop fitting side by side without one of them scrolling, which
 * would hide the very line the mock exists to point at. */
const LINES = [
  {
    source: "system",
    speaker: "Sarah",
    text: "Low. It's feature-flagged, and we kept the old path warm for a week.",
    time: "00:31",
  },
  {
    source: "mic",
    speaker: "You",
    text: "Then let's ship it. Sarah, can you draft the release note?",
    time: "00:44",
  },
  {
    source: "system",
    speaker: "Sarah",
    text: "Yep — I'll have it up by Friday.",
    time: "00:52",
  },
] as const;

/** The line that gets picked up. Index into `LINES`, not a string match — a
 * reworded transcript should break the build, not silently stop highlighting. */
const HANDOFF_INDEX = 1;

/**
 * The loop, as named beats rather than bare integers.
 *
 * `SETTLED` is both the last beat and the frame the server renders, which is
 * why it is the highest number: the mock opens finished, rewinds to `IDLE` on
 * the first tick, and plays forward again.
 */
const STEP = {
  ARRIVED: 2,
  HOLD: 3,
  IDLE: 0,
  LIT: 1,
  SETTLED: 4,
} as const;

const TOTAL_STEPS = STEP.SETTLED + 1;

/** Both panes get the same header shape so the eye reads them as one surface
 * split in two rather than two screenshots pasted together. */
const PaneHeader = ({
  label,
  trailing,
}: {
  label: string;
  trailing: string;
}) => (
  <div className="flex items-center justify-between border-white/8 border-b px-4 py-2.5">
    <span className="font-medium text-[12px] text-chrome-foreground">
      {label}
    </span>
    <span className="font-mono text-[11px] text-chrome-muted tabular-nums">
      {trailing}
    </span>
  </div>
);

export const HandoffMock = ({ className }: { className?: string }) => {
  const { active, ref, step } = useMockClock({
    initialStep: STEP.SETTLED,
    intervalMs: 1400,
    reducedStep: STEP.SETTLED,
    steps: TOTAL_STEPS,
  });

  const lit = step >= STEP.LIT;
  const arrived = step >= STEP.ARRIVED;

  return (
    <ProductFrame
      className={className}
      description="A transcript line at 00:44 becomes a linked action item in the saved Markdown note beside it."
    >
      <div className="grid sm:grid-cols-2" ref={ref}>
        {/* Left: the transcript, as it runs. */}
        <div className="min-h-[236px] border-white/8 border-b sm:border-b-0 sm:border-r">
          <PaneHeader label="Live transcript" trailing="00:44" />

          <div className="space-y-3 px-4 py-4">
            {LINES.map((line, index) => (
              <div
                className={cn(
                  "-mx-2 flex gap-3 rounded-md px-2 py-1 transition-colors duration-500 ease-out",
                  index === HANDOFF_INDEX && lit && "bg-[#ffd60a]/12"
                )}
                key={line.time}
              >
                <span className="flex w-10 shrink-0 items-center gap-1 pt-px font-mono text-[11px] text-chrome-muted tabular-nums">
                  {/* The beat between the line lighting and the note gaining
                      it. `active` is the hook's in-view-and-not-reduced-motion
                      flag, so this keyframe loop stops off-screen like every
                      other one on the page. */}
                  <span
                    className={cn(
                      "size-1 shrink-0 rounded-full bg-[#ffd60a] transition-opacity duration-300",
                      index === HANDOFF_INDEX && lit && !arrived
                        ? "opacity-100"
                        : "opacity-0",
                      active && "animate-pulse"
                    )}
                  />
                  {line.time}
                </span>
                <p className="min-w-0 text-[13px] leading-relaxed">
                  <span
                    className={cn(
                      "mr-2 font-semibold",
                      line.source === "mic"
                        ? "text-cerulean-chrome"
                        : "text-[#c7b8a1]"
                    )}
                  >
                    {line.speaker}
                  </span>
                  <span className="text-chrome-foreground/85">{line.text}</span>
                </p>
              </div>
            ))}
          </div>
        </div>

        {/* Right: the note on disk, gaining the line. */}
        <div className="min-h-[236px]">
          <PaneHeader label="Standup.md" trailing="Action Items" />

          <div className="px-4 py-4 font-mono text-[11px] leading-[1.75] sm:text-[12px]">
            <p className="text-[#7fb4e8]">## Action Items</p>

            <p className="mt-2 text-[#9ed7a4]">
              - [ ] Marcus: Send the demo runbook to sales
            </p>

            {/* The arrival. Reserved by the pane's `min-h` whether or not it is
                showing, so it can never push the rows under it. */}
            <p
              className={cn(
                "mt-1.5 text-[#9ed7a4] transition-[opacity,filter,transform] duration-500 ease-out",
                arrived
                  ? "translate-y-0 opacity-100 blur-0"
                  : "translate-y-1 opacity-0 blur-[3px]"
              )}
            >
              - [ ] Sarah: Draft the release note — cover the flag and the
              rollback path (by Friday){" "}
              <span className="text-cerulean-chrome underline decoration-cerulean/40">
                [[#00:44|00:44]]
              </span>
            </p>

            <p
              className={cn(
                "mt-4 text-[11px] text-chrome-muted transition-opacity duration-500",
                arrived ? "opacity-100" : "opacity-0"
              )}
            >
              Written from the transcript. No typing.
            </p>
          </div>
        </div>
      </div>
    </ProductFrame>
  );
};
