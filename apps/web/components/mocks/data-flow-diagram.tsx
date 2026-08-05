import { cn } from "@/lib/utils";

const HOPS = [
  {
    body: "Audio is captured and mixed locally. Your keys sit in the Keychain.",
    note: "on your Mac",
    title: "Convene",
  },
  {
    body: "Audio streams here for transcription, over your own key. Required.",
    note: "your key, billed to you",
    title: "AssemblyAI",
  },
  {
    body: "The transcript goes here for the summary. Skip it and you still get the transcript.",
    note: "your key · optional",
    title: "Anthropic or OpenAI",
  },
  {
    body: "The finished note is written into the folder you picked.",
    note: "on your Mac",
    title: "Your folder",
  },
] as const;

export const DataFlowDiagram = ({ className }: { className?: string }) => (
  <figure className={cn("not-prose", className)}>
    <figcaption className="sr-only">
      How data moves. Convene captures audio on your Mac and holds your API keys
      in the Keychain. Audio streams to AssemblyAI for transcription using your
      own key, which is required. The transcript optionally goes to Anthropic or
      OpenAI for a summary, again with your own key. The finished Markdown note
      is written to a folder on your Mac. There is no Convene server anywhere in
      that path: no step routes through us.
    </figcaption>

    <ol aria-hidden="true" className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
      {HOPS.map((hop, index) => (
        <li
          className="relative flex flex-col rounded-xl bg-card p-4 lg:p-5"
          key={hop.title}
        >
          <span className="font-mono text-[11px] text-muted-foreground tabular-nums">
            {String(index + 1).padStart(2, "0")}
          </span>
          <span className="mt-2 font-medium text-base">{hop.title}</span>
          <span
            className={cn(
              "mt-1 w-fit rounded-full px-2 py-0.5 text-[11px]",
              hop.note.startsWith("on your Mac")
                ? "bg-cerulean/10 text-link"
                : "bg-secondary text-muted-foreground"
            )}
          >
            {hop.note}
          </span>
          <span className="mt-3 text-muted-foreground text-sm leading-relaxed">
            {hop.body}
          </span>
        </li>
      ))}
    </ol>

    <p
      className="mt-3 flex items-center justify-center gap-2 rounded-xl border border-dashed px-4 py-3 text-center text-muted-foreground text-sm"
      aria-hidden="true"
    >
      <span className="line-through decoration-2">Convene server</span>
      <span>does not exist, so nothing can route through it</span>
    </p>
  </figure>
);
