"use client";
"use no memo";

import { cn } from "@/lib/utils";

import { ProductFrame } from "./product-frame";
import { useMockClock } from "./use-mock-clock";

interface ScheduleEvent {
  done: boolean;
  live: boolean;
  service: string | null;
  time: string;
  title: string;
}

const SCHEDULE: ScheduleEvent[] = [
  {
    done: true,
    live: false,
    service: "Zoom",
    time: "9:00",
    title: "Design review",
  },
  {
    done: false,
    live: true,
    service: "Google Meet",
    time: "10:30",
    title: "Standup",
  },
  {
    done: false,
    live: false,
    service: "Teams",
    time: "14:00",
    title: "Pricing sync — Acme",
  },
  {
    done: false,
    live: false,
    service: null,
    time: "16:30",
    title: "1:1 with Sarah",
  },
];

/** 6s idle, then 14s recording, ticking once a second so the elapsed timer
 * reads as live rather than as a frozen screenshot. */
const IDLE_STEPS = 6;
const TOTAL_STEPS = 20;

const elapsedLabel = (seconds: number) => {
  // Picks up mid-meeting at 4:12 rather than 0:00, so it reads as a call in
  // progress rather than one that just started.
  const total = 252 + seconds;
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
};

const MenuBarGlyphs = () => (
  <div className="flex items-center gap-3 text-chrome-muted">
    {/* Battery */}
    <svg
      aria-hidden="true"
      fill="none"
      height="11"
      viewBox="0 0 26 12"
      width="26"
    >
      <rect
        height="11"
        opacity="0.5"
        rx="3"
        stroke="currentColor"
        width="22"
        x="0.5"
        y="0.5"
      />
      <rect fill="currentColor" height="7" rx="1.5" width="15" x="2" y="2.5" />
      <path d="M24 4v4a2 2 0 0 0 0-4z" fill="currentColor" opacity="0.5" />
    </svg>
    {/* Wi-Fi */}
    <svg
      aria-hidden="true"
      fill="currentColor"
      height="12"
      viewBox="0 0 16 12"
      width="16"
    >
      <path d="M8 10.5 6 8.2a3 3 0 0 1 4 0l-2 2.3Z" />
      <path
        d="M8 3.2c2 0 3.9.8 5.3 2.1l1.2-1.4A9.4 9.4 0 0 0 8 1.3a9.4 9.4 0 0 0-6.5 2.6l1.2 1.4A7.7 7.7 0 0 1 8 3.2Z"
        opacity="0.55"
      />
      <path
        d="M8 6.1c1.2 0 2.3.5 3.1 1.2l1.2-1.4A6.5 6.5 0 0 0 8 4.3c-1.6 0-3.1.6-4.3 1.6l1.2 1.4A4.6 4.6 0 0 1 8 6.1Z"
        opacity="0.75"
      />
    </svg>
    <span className="font-medium text-[12px] text-chrome-foreground tabular-nums">
      Tue 10:23
    </span>
  </div>
);

export const MenuBarMock = ({ className }: { className?: string }) => {
  const { active, ref, step } = useMockClock({
    intervalMs: 1000,
    reducedStep: 2,
    steps: TOTAL_STEPS,
  });

  const isRecording = step >= IDLE_STEPS;
  const elapsed = elapsedLabel(step - IDLE_STEPS);

  return (
    <ProductFrame
      className={className}
      description="The Convene menu bar item on macOS, showing a countdown pill that reads “Standup, in 7 minutes”. Its popover lists today's schedule: Design review at 9:00, Standup at 10:30, Pricing sync with Acme at 14:00, and a 1:1 with Sarah at 16:30. There is a Record button, and actions to join and record the current meeting, join it without recording, or open it in Calendar. While recording, the header shows a red dot and a running timer."
    >
      <div className="select-none" ref={ref}>
        {/* Desktop backdrop, so the menu bar reads as sitting on a screen. */}
        <div className="bg-[linear-gradient(150deg,#3d4a5c_0%,#55606f_45%,#7d8189_100%)] px-3 pb-10 pt-0 sm:px-6 sm:pb-16">
          {/* The menu bar itself */}
          <div className="-mx-3 sm:-mx-6 flex h-7 items-center justify-between bg-black/25 px-3 backdrop-blur-md sm:px-4">
            <div className="flex items-center gap-3">
              <svg
                aria-hidden="true"
                className="text-chrome-foreground"
                fill="currentColor"
                height="12"
                viewBox="0 0 814 1000"
                width="10"
              >
                <path d="M788.1 340.9c-5.8 4.5-108.2 62.2-108.2 190.5 0 148.4 130.3 200.9 134.2 202.2-.6 3.2-20.7 71.9-68.7 141.9-42.8 61.6-87.5 123.1-155.5 123.1s-85.5-39.5-164-39.5c-76.5 0-103.7 40.8-165.9 40.8s-105.6-57.8-155.5-127.4c-58.3-81.8-105.3-209.2-105.3-330.3 0-194.3 126.4-297.5 250.8-297.5 66.1 0 121.2 43.4 162.7 43.4 39.5 0 101.1-46 176.3-46 28.5 0 130.9 2.6 198.3 99.2zm-234-181.5c31.1-36.9 53.1-88.1 53.1-139.3 0-7.1-.6-14.3-1.9-20.1-50.6 1.9-110.8 33.7-147.1 75.8-28.5 32.4-55.1 83.6-55.1 135.5 0 7.8.6 15.7 1.3 18.2 2.6.6 6.4 1.3 10.2 1.3 45.4 0 103.5-30.4 139.5-71.4z" />
              </svg>
              <span className="hidden font-semibold text-[12px] text-chrome-foreground sm:inline">
                Calendar
              </span>
            </div>

            <div className="flex items-center gap-2 sm:gap-3">
              {/* The Convene status item: a countdown pill, red while capturing. */}
              <div
                className={cn(
                  "flex items-center gap-1.5 rounded-md px-1.5 py-0.5 text-[11px] transition-colors duration-300",
                  isRecording
                    ? "bg-record/20 text-record"
                    : "bg-white/10 text-chrome-foreground"
                )}
              >
                <svg
                  aria-hidden="true"
                  fill="none"
                  height="11"
                  viewBox="0 0 14 14"
                  width="11"
                >
                  <g
                    stroke="currentColor"
                    strokeLinecap="round"
                    strokeWidth="1.4"
                  >
                    <path d="M2 6v2M5 4v6M8 2.5v9M11 5v4" />
                  </g>
                </svg>
                <span className="whitespace-nowrap font-medium tabular-nums">
                  {isRecording ? elapsed : "Standup · in 7m"}
                </span>
              </div>
              <MenuBarGlyphs />
            </div>
          </div>

          {/* The popover. 360pt wide in the app; it scales down on narrow screens. */}
          <div className="mt-2 flex justify-end">
            <div className="w-full max-w-[320px] origin-top-right overflow-hidden rounded-xl bg-chrome/95 shadow-2xl ring-1 ring-white/10 backdrop-blur-2xl sm:max-w-[360px]">
              {/* Header: status on the left, action on the right */}
              <div className="flex items-center justify-between px-4 py-2.5">
                {isRecording ? (
                  <div className="flex items-center gap-2">
                    <span className="relative flex size-2">
                      {active ? (
                        <span className="absolute inline-flex size-full animate-ping rounded-full bg-record opacity-70" />
                      ) : null}
                      <span className="relative inline-flex size-2 rounded-full bg-record" />
                    </span>
                    <span className="font-medium text-[12px] text-chrome-muted tabular-nums">
                      {elapsed}
                    </span>
                  </div>
                ) : (
                  <span className="font-semibold text-[13px] text-chrome-foreground">
                    Convene
                  </span>
                )}

                <div
                  className={cn(
                    "flex items-center gap-1.5 rounded-md px-2.5 py-1 font-medium text-[13px] text-white transition-colors duration-300",
                    isRecording ? "bg-record" : "bg-cerulean"
                  )}
                >
                  {isRecording ? (
                    <svg
                      aria-hidden="true"
                      fill="currentColor"
                      height="9"
                      viewBox="0 0 10 10"
                      width="9"
                    >
                      <rect height="10" rx="1.5" width="10" />
                    </svg>
                  ) : (
                    <svg
                      aria-hidden="true"
                      fill="currentColor"
                      height="10"
                      viewBox="0 0 10 10"
                      width="10"
                    >
                      <circle cx="5" cy="5" r="5" />
                    </svg>
                  )}
                  {isRecording ? "Stop" : "Record"}
                </div>
              </div>

              {/* Contextual actions for the imminent event */}
              <div className="space-y-px px-1.5 pb-1">
                {(isRecording
                  ? [
                      {
                        accent: false,
                        icon: "video",
                        label: "Join Google Meet",
                      },
                    ]
                  : [
                      {
                        accent: true,
                        icon: "record",
                        label: "Join and Record",
                      },
                      {
                        accent: false,
                        icon: "video",
                        label: "Join Google Meet",
                      },
                    ]
                ).map((action) => (
                  <div
                    className={cn(
                      "flex items-center gap-2.5 rounded-md px-2.5 py-1.5 text-[13px]",
                      action.accent
                        ? "bg-cerulean/12 text-cerulean"
                        : "text-chrome-foreground/90"
                    )}
                    key={action.label}
                  >
                    {action.icon === "record" ? (
                      <svg
                        aria-hidden="true"
                        fill="none"
                        height="13"
                        viewBox="0 0 14 14"
                        width="13"
                      >
                        <circle
                          cx="7"
                          cy="7"
                          r="5.6"
                          stroke="currentColor"
                          strokeWidth="1.3"
                        />
                        <circle cx="7" cy="7" fill="currentColor" r="2.6" />
                      </svg>
                    ) : (
                      <svg
                        aria-hidden="true"
                        fill="currentColor"
                        height="13"
                        viewBox="0 0 16 12"
                        width="13"
                      >
                        <rect height="10" rx="2" width="11" y="1" />
                        <path d="M12.5 5.2 16 3v6l-3.5-2.2v-1.6Z" />
                      </svg>
                    )}
                    {action.label}
                  </div>
                ))}
                <div className="flex items-center gap-2.5 rounded-md px-2.5 py-1.5 text-[13px] text-chrome-foreground/90">
                  <svg
                    aria-hidden="true"
                    fill="none"
                    height="13"
                    viewBox="0 0 14 14"
                    width="13"
                  >
                    <rect
                      height="10.5"
                      rx="2"
                      stroke="currentColor"
                      strokeWidth="1.3"
                      width="12"
                      x="1"
                      y="2.5"
                    />
                    <path
                      d="M1 6h12M4.5 1v3M9.5 1v3"
                      stroke="currentColor"
                      strokeWidth="1.3"
                    />
                  </svg>
                  Open in Calendar
                </div>
              </div>

              <div className="mx-3 h-px bg-white/8" />

              {/* Today's schedule */}
              <div className="px-4 pt-3 pb-1">
                <span className="font-medium text-[11px] text-chrome-muted uppercase tracking-wider">
                  Today, 9 June
                </span>
              </div>
              <div className="space-y-px px-1.5 pb-2">
                {SCHEDULE.map((event) => (
                  <div
                    className={cn(
                      "flex items-center gap-3 rounded-md px-2.5 py-1.5",
                      event.live && "bg-white/6"
                    )}
                    key={event.title}
                  >
                    <span
                      className={cn(
                        "w-9 shrink-0 font-medium text-[12px] tabular-nums",
                        event.done
                          ? "text-chrome-muted/50"
                          : "text-chrome-muted"
                      )}
                    >
                      {event.time}
                    </span>
                    <span
                      className={cn(
                        "min-w-0 flex-1 truncate text-[13px]",
                        event.done
                          ? "text-chrome-muted/50 line-through"
                          : "text-chrome-foreground/90"
                      )}
                    >
                      {event.title}
                    </span>
                    {event.service ? (
                      <span className="shrink-0 rounded bg-white/8 px-1.5 py-0.5 text-[10px] text-chrome-muted">
                        {event.service}
                      </span>
                    ) : null}
                  </div>
                ))}
              </div>

              <div className="flex items-center justify-between border-white/8 border-t px-3.5 py-2 text-[11px] text-chrome-muted">
                <span>Settings</span>
                <span aria-hidden="true">···</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </ProductFrame>
  );
};
