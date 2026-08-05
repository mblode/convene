import { cn } from "@/lib/utils";

import { NOTE_FILENAME } from "./note-data";
import { ProductFrame } from "./product-frame";

const VAULT = [
  { depth: 0, kind: "folder", name: "Work" },
  { depth: 1, kind: "folder", name: "Meetings" },
  { depth: 2, kind: "file", name: "2026-06-05 — Design review.md" },
  { active: true, depth: 2, kind: "file", name: "2026-06-09 — Standup.md" },
  { depth: 2, kind: "file", name: "2026-06-09 — Pricing sync.md" },
  { depth: 1, kind: "folder", name: "Projects" },
] as const;

export const ObsidianMock = ({ className }: { className?: string }) => (
  <ProductFrame
    className={className}
    description={`The same note open in an Obsidian vault. A file tree shows Work, then Meetings, containing one Markdown file per meeting, with "${NOTE_FILENAME}" selected. The note renders with its title, a Key Moments list whose 00:38 link jumps to that point in the transcript, a TL;DR, and an action item checkbox for the release note assigned to Sarah. Convene wrote the file straight into the vault. There is no import step.`}
  >
    <div className="flex min-h-[300px]">
      {/* File tree */}
      <div className="hidden w-[190px] shrink-0 border-white/8 border-r bg-black/20 py-3 sm:block">
        <div className="px-3 pb-2 font-medium text-[10px] text-chrome-muted uppercase tracking-wider">
          Vault
        </div>
        {VAULT.map((entry) => (
          <div
            className={cn(
              "flex items-center gap-1.5 py-[3px] pr-2 text-[11px]",
              "active" in entry && entry.active
                ? "bg-white/8 text-chrome-foreground"
                : "text-chrome-muted"
            )}
            key={entry.name}
            style={{ paddingLeft: `${12 + entry.depth * 12}px` }}
          >
            {entry.kind === "folder" ? (
              <svg
                aria-hidden="true"
                fill="currentColor"
                height="10"
                viewBox="0 0 12 10"
                width="10"
              >
                <path d="M0 1.5A1.5 1.5 0 0 1 1.5 0h2.7l1.2 1.4h5.1A1.5 1.5 0 0 1 12 2.9v5.6A1.5 1.5 0 0 1 10.5 10h-9A1.5 1.5 0 0 1 0 8.5v-7Z" />
              </svg>
            ) : (
              <span
                aria-hidden="true"
                className="w-[10px] text-center text-[9px] opacity-60"
              >
                ▪
              </span>
            )}
            <span className="truncate">{entry.name}</span>
          </div>
        ))}
      </div>

      {/* Rendered note */}
      <div className="min-w-0 flex-1 px-5 py-4 sm:px-7 sm:py-6">
        <h3 className="font-semibold text-[19px] text-chrome-foreground">
          Standup
        </h3>
        <p className="mt-1 text-[11px] text-chrome-muted">
          9 June 2026 · 14 min · Sarah Chen, Marcus Webb
        </p>

        <p className="mt-5 font-semibold text-[12px] text-chrome-foreground/70 uppercase tracking-wider">
          Key Moments
        </p>
        <p className="mt-1.5 text-[13px]">
          <span className="text-cerulean underline decoration-cerulean/40">
            00:38
          </span>
          <span className="text-chrome-foreground/70"> — Ship decision</span>
        </p>

        <p className="mt-5 font-semibold text-[12px] text-chrome-foreground/70 uppercase tracking-wider">
          TL;DR
        </p>
        <p className="mt-1.5 max-w-[52ch] text-[13px] text-chrome-foreground/80 leading-relaxed">
          The auth migration shipped overnight behind a feature flag, with the
          previous code path kept warm for a week. Rollback risk was judged low
          enough to proceed ahead of Thursday’s enterprise demo.
        </p>

        <p className="mt-5 font-semibold text-[12px] text-chrome-foreground/70 uppercase tracking-wider">
          Action Items
        </p>
        {/* A drawing of a checkbox, not a control — this is a picture of a note. */}
        <div className="mt-1.5 flex items-start gap-2 text-[13px] text-chrome-foreground/80">
          <span className="mt-[3px] size-3 shrink-0 rounded-[3px] border border-chrome-muted/60" />
          <span>
            <span className="font-medium text-chrome-foreground">Sarah:</span>{" "}
            Draft the release note — cover the flag and the rollback path (by
            Friday)
          </span>
        </div>
      </div>
    </div>
  </ProductFrame>
);
