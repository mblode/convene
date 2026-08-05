"use client";
"use no memo";

import { cn } from "@/lib/utils";

import { ProductFrame } from "./product-frame";
import { useMockClock } from "./use-mock-clock";

/** Drawn to match the real popover in the light appearance: a translucent
 * panel, a status circle tinted with the event's calendar colour, the time
 * range as quiet metadata ahead of the title, and either a countdown pill or
 * an attendee count trailing. Layout mirrors Convene/UI/Components/EventRow.swift. */
interface ScheduleEvent {
  attendees?: number;
  /** The calendar's own colour, as EventKit hands it over. */
  color: string;
  pill?: string;
  status: "past" | "upcoming";
  time: string;
  title: string;
}

const SCHEDULE: ScheduleEvent[] = [
  {
    attendees: 3,
    color: "#0a84ff",
    status: "past",
    time: "9:00 am – 9:30 am",
    title: "Design review",
  },
  {
    color: "#0a84ff",
    pill: "in 7m",
    status: "upcoming",
    time: "10:30 am – 11:00 am",
    title: "Standup",
  },
  {
    attendees: 4,
    color: "#ff9f0a",
    status: "upcoming",
    time: "2:00 pm – 2:30 pm",
    title: "Pricing sync with Acme",
  },
  {
    attendees: 1,
    color: "#30d158",
    status: "upcoming",
    time: "4:30 pm – 5:00 pm",
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

const StatusCircle = ({
  color,
  status,
}: {
  color: string;
  status: ScheduleEvent["status"];
}) => {
  if (status === "past") {
    return (
      <span
        className="flex size-3.5 shrink-0 items-center justify-center rounded-full"
        style={{ backgroundColor: `${color}2e` }}
      >
        <svg
          aria-hidden="true"
          fill="none"
          height="7"
          viewBox="0 0 10 8"
          width="8"
        >
          <path
            d="M1 4.2 3.4 6.6 9 1"
            stroke={color}
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth="1.8"
          />
        </svg>
      </span>
    );
  }
  return (
    <span
      className="size-3.5 shrink-0 rounded-full border-[1.5px]"
      style={{ borderColor: color }}
    />
  );
};

const AttendeeCount = ({ count }: { count: number }) => (
  <span className="flex shrink-0 items-center gap-[3px] text-[#6e6e73]">
    <svg
      aria-hidden="true"
      fill="currentColor"
      height="10"
      viewBox="0 0 12 13"
      width="9"
    >
      <circle cx="6" cy="3.4" r="2.9" />
      <path d="M6 7.2c-3 0-5 1.8-5 4 0 .8.6 1.3 1.4 1.3h7.2c.8 0 1.4-.5 1.4-1.3 0-2.2-2-4-5-4Z" />
    </svg>
    <span className="tabular-nums">{count}</span>
  </span>
);

const MenuBarGlyphs = () => (
  <div className="flex items-center gap-3 text-white/85">
    <svg
      aria-hidden="true"
      fill="none"
      height="11"
      viewBox="0 0 26 12"
      width="24"
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
    <svg
      aria-hidden="true"
      fill="currentColor"
      height="11"
      viewBox="0 0 16 12"
      width="15"
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
    <span className="whitespace-nowrap font-medium text-[12px] text-white tabular-nums">
      Wed 5 Aug 10:23
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
      description="The Convene menu bar item on macOS. Its status item shows a countdown reading “Standup, in 7 minutes”, and the popover below lists today's schedule: Design review from 9:00 to 9:30 with 3 people and already finished, Standup from 10:30 to 11:00 starting in 7 minutes, Pricing sync with Acme from 2:00 to 2:30 with 4 people, and a 1:1 with Sarah from 4:30 to 5:00. Each row carries a circle tinted with its calendar colour. A Record button sits in the header, and while recording it becomes a red Stop button beside a running timer."
    >
      <div className="select-none" ref={ref}>
        {/* Desktop backdrop, so the menu bar reads as sitting on a screen. */}
        <div className="bg-[linear-gradient(150deg,#2f3a49_0%,#46505f_45%,#6d727b_100%)] px-3 pb-8 sm:px-6 sm:pb-12">
          {/* The menu bar itself */}
          <div className="-mx-3 sm:-mx-6 flex h-7 items-center justify-end gap-2 bg-black/30 px-3 backdrop-blur-md sm:gap-3 sm:px-4">
            {/* The Convene status item, highlighted the way macOS marks an open popover. */}
            <div
              className={cn(
                "flex items-center gap-1.5 rounded-[5px] bg-white/95 px-1.5 py-0.5 text-[11px]",
                isRecording ? "text-[#ff3b30]" : "text-[#1d1d1f]"
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

          {/* The popover. 360pt wide in the app, hanging from the status item. */}
          <div className="mt-1.5 flex justify-end">
            <div className="w-full max-w-[330px] sm:max-w-[360px]">
              {/* The tail that points back at the status item. */}
              <div className="flex justify-start pl-5">
                <span
                  aria-hidden="true"
                  className="block size-0 border-[7px] border-transparent border-b-[#ececed]"
                />
              </div>

              <div className="overflow-hidden rounded-[12px] bg-[#ececed]/95 shadow-2xl ring-1 ring-black/10 backdrop-blur-2xl">
                {/* Header: status on the left, action on the right */}
                <div className="flex items-center justify-between px-4 pt-3 pb-1">
                  {isRecording ? (
                    <div className="flex items-center gap-2">
                      <span className="relative flex size-2">
                        {active ? (
                          <span className="absolute inline-flex size-full animate-ping rounded-full bg-[#ff3b30] opacity-70" />
                        ) : null}
                        <span className="relative inline-flex size-2 rounded-full bg-[#ff3b30]" />
                      </span>
                      <span className="font-medium text-[#6e6e73] text-[12px] tabular-nums">
                        {elapsed}
                      </span>
                    </div>
                  ) : (
                    <span className="font-semibold text-[#1d1d1f] text-[13px]">
                      Convene
                    </span>
                  )}

                  <div
                    className={cn(
                      "flex items-center gap-1.5 rounded-[7px] px-2.5 py-1 font-medium text-[13px] text-white transition-colors duration-300",
                      isRecording ? "bg-[#ff3b30]" : "bg-[#007aff]"
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
                        <rect height="10" rx="2" width="10" />
                      </svg>
                    ) : (
                      <svg
                        aria-hidden="true"
                        fill="none"
                        height="11"
                        viewBox="0 0 14 14"
                        width="11"
                      >
                        <circle
                          cx="7"
                          cy="7"
                          r="6"
                          stroke="currentColor"
                          strokeWidth="1.6"
                        />
                        <circle cx="7" cy="7" fill="currentColor" r="3" />
                      </svg>
                    )}
                    {isRecording ? "Stop" : "Record"}
                  </div>
                </div>

                {/* Day header */}
                <div className="px-4 pt-2 pb-1">
                  <span className="font-medium text-[#6e6e73] text-[11px]">
                    Today, 5 August
                  </span>
                </div>

                {/* Today's schedule */}
                <div className="space-y-px px-1.5 pb-1.5">
                  {SCHEDULE.map((event) => (
                    <div
                      className={cn(
                        "flex items-center gap-2.5 rounded-[7px] px-2.5 py-1.5",
                        event.status === "past" && "opacity-65"
                      )}
                      key={event.title}
                    >
                      <StatusCircle color={event.color} status={event.status} />
                      <span className="shrink-0 text-[#6e6e73] text-[11px] tabular-nums">
                        {event.time}
                      </span>
                      <span
                        className={cn(
                          "min-w-0 flex-1 truncate font-medium text-[13px]",
                          event.status === "past"
                            ? "text-[#6e6e73]"
                            : "text-[#1d1d1f]"
                        )}
                      >
                        {event.title}
                      </span>
                      {event.pill ? (
                        <span className="shrink-0 rounded-full bg-[#007aff]/12 px-[7px] py-[2px] font-semibold text-[#0060df] text-[10px]">
                          {event.pill}
                        </span>
                      ) : null}
                      {event.attendees ? (
                        <AttendeeCount count={event.attendees} />
                      ) : null}
                    </div>
                  ))}
                </div>

                {/* Footer: settings and the overflow menu, nothing else. */}
                <div className="flex items-center justify-between border-black/10 border-t px-2.5 py-1.5 text-[#6e6e73]">
                  <svg
                    aria-hidden="true"
                    fill="none"
                    height="15"
                    viewBox="0 0 16 16"
                    width="15"
                  >
                    <circle
                      cx="8"
                      cy="8"
                      r="2.4"
                      stroke="currentColor"
                      strokeWidth="1.3"
                    />
                    <path
                      d="M8 1.6v1.6M8 12.8v1.6M14.4 8h-1.6M3.2 8H1.6M12.5 3.5l-1.1 1.1M4.6 11.4l-1.1 1.1M12.5 12.5l-1.1-1.1M4.6 4.6 3.5 3.5"
                      stroke="currentColor"
                      strokeLinecap="round"
                      strokeWidth="1.3"
                    />
                  </svg>
                  <svg
                    aria-hidden="true"
                    fill="none"
                    height="15"
                    viewBox="0 0 16 16"
                    width="15"
                  >
                    <circle
                      cx="8"
                      cy="8"
                      r="6.4"
                      stroke="currentColor"
                      strokeWidth="1.3"
                    />
                    <circle cx="5.2" cy="8" fill="currentColor" r="0.9" />
                    <circle cx="8" cy="8" fill="currentColor" r="0.9" />
                    <circle cx="10.8" cy="8" fill="currentColor" r="0.9" />
                  </svg>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </ProductFrame>
  );
};
