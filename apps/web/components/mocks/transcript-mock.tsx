"use client";
"use no memo";

import { cn } from "@/lib/utils";

import { ProductFrame } from "./product-frame";
import { useMockClock } from "./use-mock-clock";

type Line =
  | {
      kind: "speech";
      source: "mic" | "system";
      speaker: string;
      text: string;
      time: string;
    }
  | { kind: "moment"; time: string };

/** The same meeting runs through every mock on the page, so the transcript,
 * the saved note and the vault view all tell one continuous story. */
const LINES: Line[] = [
  {
    kind: "speech",
    source: "mic",
    speaker: "You",
    text: "Before we start — I've got Convene running, so nobody has to take notes.",
    time: "00:04",
  },
  {
    kind: "speech",
    source: "system",
    speaker: "Sarah",
    text: "Great. Quick update: the auth migration landed last night.",
    time: "00:11",
  },
  {
    kind: "speech",
    source: "system",
    speaker: "Marcus",
    text: "Any rollback risk? We've got the enterprise demo on Thursday.",
    time: "00:23",
  },
  {
    kind: "speech",
    source: "system",
    speaker: "Sarah",
    text: "Low. It's feature-flagged, and we kept the old path warm for a week.",
    time: "00:31",
  },
  { kind: "moment", time: "00:38" },
  {
    kind: "speech",
    source: "mic",
    speaker: "You",
    text: "Then let's ship it. Sarah, can you draft the release note?",
    time: "00:44",
  },
  {
    kind: "speech",
    source: "system",
    speaker: "Sarah",
    text: "Yep — I'll have it up by Friday.",
    time: "00:52",
  },
];

/** Three extra beats at the end so the finished transcript is readable before
 * the loop restarts. */
const TOTAL_STEPS = LINES.length + 3;

export const TranscriptMock = ({ className }: { className?: string }) => {
  const { active, ref, step } = useMockClock({
    // Opens on the finished frame rather than an empty one. The clock starts
    // when the mock scrolls into view, so step 0 is not a frame a reader might
    // catch — it is the frame every reader gets first, and for the transcript
    // that meant a tall empty rectangle holding a chrome bar and a caret.
    initialStep: LINES.length,
    intervalMs: 1100,
    reducedStep: LINES.length,
    steps: TOTAL_STEPS,
  });

  return (
    <ProductFrame
      className={className}
      description="A timestamped live transcript separates microphone and system-audio speakers, with a key moment flagged at 38 seconds."
    >
      <div ref={ref}>
        {/* Title bar */}
        <div className="flex items-center gap-3 border-white/8 border-b px-4 py-3">
          <div className="flex gap-1.5" aria-hidden="true">
            <span className="size-2.5 rounded-full bg-[#ff5f57]" />
            <span className="size-2.5 rounded-full bg-[#febc2e]" />
            <span className="size-2.5 rounded-full bg-[#28c840]" />
          </div>
          <span className="ml-1 font-medium text-[13px] text-chrome-foreground">
            Standup
          </span>
          <span className="flex items-center gap-1.5 text-[12px] text-record">
            <span className="relative flex size-1.5">
              {active ? (
                <span className="absolute inline-flex size-full animate-ping rounded-full bg-record opacity-70" />
              ) : null}
              <span className="relative inline-flex size-1.5 rounded-full bg-record" />
            </span>
            Recording
          </span>
        </div>

        {/* Two capture sources, named. This is the whole point of the mock. */}
        <div className="flex flex-wrap items-center gap-x-5 gap-y-1.5 border-white/8 border-b px-4 py-2.5 text-[11px]">
          {/* Text takes `--cerulean-chrome` (4.66:1 on the chrome, up from
              `--cerulean`'s 4.22:1 at 11px); the dot keeps `--cerulean`, which
              is what that token is documented for. */}
          <span className="flex items-center gap-1.5 text-cerulean-chrome">
            <span className="size-1.5 rounded-full bg-cerulean" />
            Your mic
          </span>
          <span className="flex items-center gap-1.5 text-[#c7b8a1]">
            <span className="size-1.5 rounded-full bg-[#c7b8a1]" />
            System audio · diarized
          </span>
        </div>

        {/* Transcript */}
        <div className="min-h-[260px] space-y-3 px-4 py-4 sm:min-h-[300px]">
          {LINES.map((line, index) => {
            const visible = index < step;

            if (line.kind === "moment") {
              return (
                <div
                  className={cn(
                    "flex items-center gap-3 rounded-md border-[#ffd60a]/25 border-l-2 bg-[#ffd60a]/8 py-1.5 pr-3 pl-3 transition-[opacity,filter] duration-500 ease-out",
                    visible ? "opacity-100 blur-0" : "opacity-0 blur-[3px]"
                  )}
                  key={line.time}
                >
                  <span className="w-10 shrink-0 font-mono text-[11px] text-chrome-muted tabular-nums">
                    {line.time}
                  </span>
                  <span className="text-[13px] text-[#ffd60a]">
                    ★ Key moment
                  </span>
                  <span className="ml-auto hidden rounded bg-white/8 px-1.5 py-0.5 font-medium text-[10px] text-chrome-muted sm:inline">
                    ⌥⇧K
                  </span>
                </div>
              );
            }

            return (
              <div
                className={cn(
                  "flex gap-3 transition-[opacity,filter,transform] duration-500 ease-out",
                  visible
                    ? "translate-y-0 opacity-100 blur-0"
                    : "translate-y-1 opacity-0 blur-[3px]"
                )}
                key={line.time}
              >
                <span className="w-10 shrink-0 pt-0.5 font-mono text-[11px] text-chrome-muted tabular-nums">
                  {line.time}
                </span>
                <div className="min-w-0">
                  <span
                    className={cn(
                      "mr-2 font-semibold text-[13px]",
                      line.source === "mic"
                        ? "text-cerulean-chrome"
                        : "text-[#c7b8a1]"
                    )}
                  >
                    {line.speaker}
                  </span>
                  <span className="text-[13px] text-chrome-foreground/85 leading-relaxed">
                    {line.text}
                  </span>
                </div>
              </div>
            );
          })}

          {/* Caret while more is still arriving */}
          {step < LINES.length ? (
            <div className="flex gap-3 pl-13">
              <span
                className={cn(
                  "inline-block h-4 w-[2px] bg-chrome-muted",
                  active && "animate-pulse"
                )}
              />
            </div>
          ) : null}
        </div>
      </div>
    </ProductFrame>
  );
};
