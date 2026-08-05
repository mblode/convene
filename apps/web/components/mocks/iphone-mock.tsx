"use client";
"use no memo";

import { cn } from "@/lib/utils";

import { useMockClock } from "./use-mock-clock";

/** How many of the twelve meter bars are lit at each tick. The real meter
 * saturates from the left and fades to pale pink, so only colour changes:
 * every bar keeps its height and nothing relayouts. */
const LEVELS = [2, 5, 3, 7, 4, 2, 6, 9, 3, 5, 8, 4] as const;
const BARS = 12;
const TOTAL_STEPS = LEVELS.length;

const elapsed = (step: number) => `00:${String(step + 4).padStart(2, "0")}`;

export const IphoneMock = ({ className }: { className?: string }) => {
  const { ref, step } = useMockClock({
    intervalMs: 420,
    reducedStep: 3,
    steps: TOTAL_STEPS,
  });
  const lit = LEVELS[step] ?? LEVELS[0];

  return (
    <figure className={cn("mx-auto w-full max-w-[264px]", className)}>
      <figcaption className="sr-only">
        The Convene iPhone app while a meeting records. A sheet shows the
        meeting title, a large timer reading seven seconds, a red input level
        meter, a field to write your own notes into, and the transcript so far,
        where Speaker A says “Hey, this is a test” at one second. A blue Key
        moment button and a Stop button sit at the bottom.
      </figcaption>

      {/* Device proportions are the real ones: a 393x852pt screen inside a
          bezel scaled from the same reference, so the frame reads as a phone
          rather than a rounded rectangle. */}
      <div
        aria-hidden="true"
        className="overflow-hidden rounded-[2.9rem] bg-[#1c1c1e] p-[7px] shadow-lifted ring-1 ring-foreground/10"
        ref={ref}
      >
        <div className="flex aspect-[393/852] flex-col overflow-hidden rounded-[2.4rem] bg-[#d3d3d3]">
          {/* Status bar, with the recording indicator lit in the Dynamic Island */}
          <div className="relative flex h-9 shrink-0 items-center justify-between px-4">
            <span className="font-semibold text-[#1c1c1e] text-[11px] tabular-nums">
              12:09
            </span>
            <span className="-translate-x-1/2 absolute top-1.5 left-1/2 flex h-[22px] w-[74px] items-center justify-end rounded-full bg-black pr-2.5">
              <span className="size-[5px] rounded-full bg-[#ff9500]" />
            </span>
            <span className="flex items-center gap-[3px] text-[#1c1c1e]">
              <svg
                aria-hidden="true"
                fill="currentColor"
                height="8"
                viewBox="0 0 16 10"
                width="12"
              >
                <rect height="3" rx="1" width="2.4" x="0" y="7" />
                <rect height="5" rx="1" width="2.4" x="3.4" y="5" />
                <rect height="7" rx="1" width="2.4" x="6.8" y="3" />
                <rect
                  height="10"
                  opacity="0.3"
                  rx="1"
                  width="2.4"
                  x="10.2"
                  y="0"
                />
              </svg>
              <svg
                aria-hidden="true"
                fill="currentColor"
                height="8"
                viewBox="0 0 16 12"
                width="11"
              >
                <path d="M8 10.4 6.1 8.2a2.9 2.9 0 0 1 3.8 0L8 10.4Z" />
                <path d="M8 3.1c2 0 3.9.8 5.3 2.1l1.2-1.4A9.3 9.3 0 0 0 8 1.2a9.3 9.3 0 0 0-6.5 2.6l1.2 1.4A7.6 7.6 0 0 1 8 3.1Z" />
                <path d="M8 6c1.2 0 2.3.5 3.1 1.2l1.2-1.4A6.4 6.4 0 0 0 8 4.2c-1.6 0-3.1.6-4.3 1.6l1.2 1.4A4.5 4.5 0 0 1 8 6Z" />
              </svg>
              <svg
                aria-hidden="true"
                fill="none"
                height="9"
                viewBox="0 0 26 12"
                width="15"
              >
                <rect
                  height="11"
                  opacity="0.35"
                  rx="3"
                  stroke="currentColor"
                  width="22"
                  x="0.5"
                  y="0.5"
                />
                <rect
                  fill="currentColor"
                  height="7"
                  rx="1.5"
                  width="14"
                  x="2"
                  y="2.5"
                />
                <path
                  d="M24 4v4a2 2 0 0 0 0-4z"
                  fill="currentColor"
                  opacity="0.35"
                />
              </svg>
            </span>
          </div>

          {/* The recording sheet */}
          <div className="flex flex-1 flex-col rounded-t-[14px] bg-white pt-1.5">
            <span className="mx-auto mb-2.5 block h-[3px] w-9 rounded-full bg-black/20" />

            <div className="flex items-start justify-between gap-1.5 px-3">
              <span className="truncate font-semibold text-[#000] text-[10.5px]">
                Meeting on Wednesday, Aug 5 at 12:09 pm
              </span>
              <span className="shrink-0 pt-0.5 font-bold text-[#000] text-[11px] leading-none tracking-[0.06em]">
                ···
              </span>
            </div>

            {/* Timer, the loudest thing on the screen */}
            <span className="mt-6 text-center font-light text-[#000] text-[42px] leading-none tracking-[-0.04em] tabular-nums">
              {elapsed(step)}
            </span>

            {/* Level meter: colour only, so nothing relayouts on each tick */}
            <div className="mt-3.5 flex items-center justify-center gap-[5px]">
              {Array.from({ length: BARS }, (_, index) => (
                <span
                  className="h-[17px] w-[5px] rounded-full transition-colors duration-200 ease-out"
                  key={`${index}-bar`}
                  style={{
                    backgroundColor:
                      index < lit
                        ? `rgba(201,55,44,${1 - index * 0.08})`
                        : "rgba(201,55,44,0.13)",
                  }}
                />
              ))}
            </div>

            <p className="mt-5 min-h-[58px] px-3.5 text-[#adadb2] text-[11px]">
              Write your notes here...
            </p>

            <div className="h-px bg-black/8" />

            <div className="px-3.5 pt-3">
              <p className="flex items-baseline gap-1.5">
                <span className="font-semibold text-[#000] text-[11px]">
                  Speaker A
                </span>
                <span className="font-mono text-[#8e8e93] text-[9px] tabular-nums">
                  00:01
                </span>
              </p>
              <p className="mt-0.5 text-[#000] text-[11px]">
                Hey, this is a test.
              </p>
            </div>

            {/* Absorbs the remaining height, the way the real screen does */}
            <div className="flex-1" />

            {/* Action bar */}
            <div className="flex items-center gap-2 bg-[#f2f2f7] px-3 pt-2.5 pb-4">
              <span className="flex flex-1 items-center justify-center gap-1.5 rounded-full bg-[#007aff] py-2 font-medium text-[11px] text-white">
                <svg
                  aria-hidden="true"
                  fill="none"
                  height="11"
                  viewBox="0 0 12 14"
                  width="10"
                >
                  <path
                    d="M1.6 1.2v11.4M1.6 1.9h7.2l-1.5 2.6 1.5 2.6H1.6"
                    stroke="currentColor"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="1.4"
                  />
                </svg>
                Key moment
              </span>
              <span className="flex items-center justify-center gap-1.5 rounded-full bg-white px-4 py-2 font-medium text-[#d70015] text-[11px] shadow-sm ring-1 ring-black/5">
                <span className="size-2.5 rounded-[2px] bg-[#d70015]" />
                Stop
              </span>
            </div>
          </div>
        </div>
      </div>
    </figure>
  );
};
