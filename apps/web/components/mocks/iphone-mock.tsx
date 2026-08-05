"use client";
"use no memo";

import { cn } from "@/lib/utils";

import { useMockClock } from "./use-mock-clock";

/** Level-meter bar heights, cycled so the meter reads as live audio. */
const LEVELS = [
  [30, 62, 44, 78, 52, 36, 68, 46, 24, 58, 40, 72],
  [48, 34, 70, 46, 84, 40, 30, 62, 52, 38, 66, 44],
  [62, 78, 36, 54, 32, 70, 46, 38, 74, 50, 30, 60],
  [38, 46, 58, 88, 42, 52, 34, 76, 44, 66, 36, 50],
] as const;

export const IphoneMock = ({ className }: { className?: string }) => {
  const { ref, step } = useMockClock({
    intervalMs: 420,
    reducedStep: 0,
    steps: LEVELS.length,
  });
  const levels = LEVELS[step] ?? LEVELS[0];

  return (
    <figure className={cn("mx-auto w-full max-w-[268px]", className)}>
      <figcaption className="sr-only">
        The Convene iPhone app mid-recording. A sheet shows the meeting title
        “Roadmap workshop”, a running timer at 12 minutes 04 seconds, a live
        input level meter, a notes field the user has typed into, the transcript
        separated into Speaker A and Speaker B by diarization, a Key moment
        button, and a Stop button.
      </figcaption>

      <div
        aria-hidden="true"
        className="relative overflow-hidden rounded-[2.4rem] bg-chrome p-2 shadow-lifted ring-1 ring-foreground/10"
        ref={ref}
      >
        <div className="relative overflow-hidden rounded-[1.9rem] bg-[#0d0d0f]">
          {/* Status bar + Dynamic Island */}
          <div className="relative flex items-center justify-between px-5 pt-3 pb-1">
            <span className="font-semibold text-[11px] text-chrome-foreground tabular-nums">
              9:41
            </span>
            <span className="-translate-x-1/2 absolute top-2.5 left-1/2 h-[22px] w-[70px] rounded-full bg-black" />
            <span className="text-[10px] text-chrome-muted">▮▮ ▲</span>
          </div>

          {/* Recording sheet */}
          <div className="mt-2 rounded-t-[1.4rem] bg-chrome-raised px-4 pt-3 pb-4">
            <span className="mx-auto mb-3 block h-1 w-9 rounded-full bg-white/20" />

            <div className="flex items-baseline justify-between">
              <span className="truncate font-semibold text-[14px] text-chrome-foreground">
                Roadmap workshop
              </span>
              <span className="ml-2 shrink-0 font-mono text-[13px] text-record tabular-nums">
                12:04
              </span>
            </div>

            {/* Live level meter. Bars scale rather than resize: animating
                height would relayout twelve elements every 420ms, forever. */}
            <div className="mt-3 flex h-8 items-end gap-[3px]">
              {levels.map((height, index) => (
                <span
                  className="h-full flex-1 origin-bottom rounded-full bg-cerulean/70 transition-transform duration-300 ease-out"
                  key={`${index}-bar`}
                  style={{ transform: `scaleY(${height / 100})` }}
                />
              ))}
            </div>

            {/* Notes the user typed during the meeting — iPhone-only surface */}
            <div className="mt-3 rounded-lg bg-black/30 px-3 py-2">
              <span className="text-[10px] text-chrome-muted">Your notes</span>
              <p className="mt-0.5 text-[12px] text-chrome-foreground/85 leading-snug">
                Push the pricing page to Q4 — check with Priya first
              </p>
            </div>

            {/* Diarized transcript: one mic, speakers split by the model */}
            <div className="mt-3 space-y-2">
              {[
                {
                  speaker: "Speaker A",
                  text: "Can we get the pricing page out before the offsite?",
                },
                {
                  speaker: "Speaker B",
                  text: "Only if design lands Tuesday. Otherwise it's Q4.",
                },
              ].map((line) => (
                <div className="flex gap-2" key={line.speaker}>
                  <span className="w-[52px] shrink-0 font-medium text-[10px] text-[#c7b8a1]">
                    {line.speaker}
                  </span>
                  <span className="text-[11px] text-chrome-foreground/75 leading-snug">
                    {line.text}
                  </span>
                </div>
              ))}
            </div>

            <div className="mt-4 flex gap-2">
              <span className="flex-1 rounded-full bg-white/10 py-2 text-center font-medium text-[12px] text-chrome-foreground">
                ★ Key moment
              </span>
              <span className="rounded-full bg-record px-5 py-2 text-center font-medium text-[12px] text-white">
                Stop
              </span>
            </div>
          </div>
        </div>
      </div>
    </figure>
  );
};
