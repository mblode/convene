import { Fragment } from "react";
import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

import { NOTE_FILENAME, NOTE_MARKDOWN } from "./note-data";
import { ProductFrame } from "./product-frame";

/** Colours a line of the saved note. Deliberately line-based rather than a
 * real parser: this is a display of one fixed file, not an editor. */
const lineClass = (line: string, inFrontmatter: boolean) => {
  if (inFrontmatter || line === "---") {
    return "text-[#8b9bb4]";
  }
  if (line.startsWith("# ")) {
    return "font-semibold text-chrome-foreground";
  }
  if (line.startsWith("#")) {
    return "font-medium text-[#7fb4e8]";
  }
  if (line.startsWith(">")) {
    return "text-[#ffd60a]";
  }
  if (line.startsWith("- [ ]")) {
    return "text-[#9ed7a4]";
  }
  if (line.startsWith("- ")) {
    return "text-chrome-foreground/80";
  }
  return "text-chrome-foreground/70";
};

/** Marks up `[[#00:38|00:38]]` wikilinks and `**Speaker:**` labels inside a
 * line so the note reads as the structured thing it is. */
const TOKEN = /\[\[[^\]]+\]\]|\*\*[^*]+\*\*/gu;

const renderInline = (line: string) => {
  const nodes: ReactNode[] = [];
  let cursor = 0;

  for (const match of line.matchAll(TOKEN)) {
    const start = match.index ?? 0;
    const [token] = match;
    if (start > cursor) {
      const text = line.slice(cursor, start);
      nodes.push(<Fragment key={`t${start}`}>{text}</Fragment>);
    }
    nodes.push(
      token.startsWith("[[") ? (
        // Wikilinks are 11px text on the chrome: `--cerulean` measures 4.22:1
        // there, under the 4.5:1 AA minimum. `--cerulean-chrome` is 4.66:1.
        // The underline keeps the softer `--cerulean` tint — it is a
        // decorative rule, not text, so 3:1 is the bar it has to clear.
        <span
          className="text-cerulean-chrome underline decoration-cerulean/40"
          key={`w${start}`}
        >
          {token}
        </span>
      ) : (
        <span
          className="font-semibold text-chrome-foreground"
          key={`b${start}`}
        >
          {token}
        </span>
      )
    );
    cursor = start + token.length;
  }

  if (cursor < line.length) {
    nodes.push(<Fragment key={`t${cursor}`}>{line.slice(cursor)}</Fragment>);
  }
  return nodes;
};

/** Tags each line with whether it sits inside the YAML frontmatter, computed
 * up front rather than by mutating a counter while rendering. */
const classifyLines = () => {
  let fences = 0;
  return NOTE_MARKDOWN.split("\n").map((text) => {
    const isFence = text === "---" && fences < 2;
    if (isFence) {
      fences += 1;
    }
    return { inFrontmatter: !isFence && fences === 1, isFence, text };
  });
};

const LINES = classifyLines();

export const MarkdownNoteMock = ({ className }: { className?: string }) => (
  <ProductFrame
    className={className}
    description={`The file Convene saves, named "${NOTE_FILENAME}". It opens with YAML frontmatter recording the title, date, duration, attendees, and which model wrote the summary. Then a Key Moments index linking to 00:38, a TL;DR paragraph, the decision to ship the auth migration, an unchecked action item for Sarah to draft the release note by Friday, and the full transcript under timestamped headings. It is a plain Markdown file on disk.`}
  >
    <div>
      <div className="flex items-center gap-2.5 border-white/8 border-b px-4 py-2.5">
        <svg
          aria-hidden="true"
          className="shrink-0 text-chrome-muted"
          fill="none"
          height="14"
          viewBox="0 0 14 16"
          width="13"
        >
          <path
            d="M8.2 1H3a1.5 1.5 0 0 0-1.5 1.5v11A1.5 1.5 0 0 0 3 15h8a1.5 1.5 0 0 0 1.5-1.5V5.3L8.2 1Z"
            stroke="currentColor"
            strokeWidth="1.2"
          />
          <path d="M8 1.2v4.3h4.3" stroke="currentColor" strokeWidth="1.2" />
        </svg>
        <span className="truncate font-mono text-[11px] text-chrome-muted">
          {NOTE_FILENAME}
        </span>
      </div>

      <pre className="max-h-[420px] overflow-hidden px-4 py-3.5 font-mono text-[11px] leading-[1.75] sm:text-[12px]">
        <code>
          {LINES.map((line, index) => (
            <div
              className={cn(
                "whitespace-pre-wrap",
                line.isFence
                  ? "text-[#8b9bb4]"
                  : lineClass(line.text, line.inFrontmatter)
              )}
              key={`${index}-${line.text.slice(0, 12)}`}
            >
              {line.text === "" ? " " : renderInline(line.text)}
            </div>
          ))}
        </code>
      </pre>
    </div>
  </ProductFrame>
);
