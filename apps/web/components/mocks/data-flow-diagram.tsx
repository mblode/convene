import { cn } from "@/lib/utils";

/** Four hops, a label each. The elaboration that used to sit under every card
 * said what the label already says, and the FAQ answers the rest. */
const HOPS = [
  { note: "on your Mac", title: "Convene" },
  { note: "your key · required", title: "AssemblyAI" },
  { note: "your key · optional", title: "Anthropic or OpenAI" },
  { note: "on your Mac", title: "Your folder" },
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
      {HOPS.map((hop) => (
        <li className="rounded-xl bg-card p-4" key={hop.title}>
          <p className="font-medium">{hop.title}</p>
          <p
            className={cn(
              "mt-1.5 w-fit rounded-full px-2 py-0.5 text-[11px]",
              hop.note === "on your Mac"
                ? "bg-cerulean/10 text-link"
                : "bg-secondary text-muted-foreground"
            )}
          >
            {hop.note}
          </p>
        </li>
      ))}
    </ol>

    <p
      aria-hidden="true"
      className="mt-3 rounded-xl border border-dashed px-4 py-3 text-center text-muted-foreground text-sm"
    >
      <span className="line-through decoration-2">Convene server</span> does not
      exist, so nothing can route through it
    </p>
  </figure>
);
