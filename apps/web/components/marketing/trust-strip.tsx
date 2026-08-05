import { Container } from "@/components/ui/section";
import { siteConfig } from "@/lib/config";

/** Only claims a visitor could check for themselves. No star count, no user
 * number, no compliance badge — this audience punishes an unsourced figure
 * harder than it rewards one. */
const FACTS = [
  "MIT licensed",
  "No account",
  "Your notes are files",
  "Sandboxed and notarised",
] as const;

export const TrustStrip = () => (
  <div className="border-border/60 border-y bg-card/40">
    <Container>
      <ul className="flex flex-wrap items-center justify-center gap-x-6 gap-y-2 py-4 text-muted-foreground text-sm">
        {FACTS.map((fact) => (
          <li className="flex items-center gap-2" key={fact}>
            <span
              aria-hidden="true"
              className="size-1 rounded-full bg-cerulean"
            />
            {fact}
          </li>
        ))}
        <li className="flex items-center gap-2">
          <span
            aria-hidden="true"
            className="size-1 rounded-full bg-cerulean"
          />
          <a
            className="rounded underline decoration-border underline-offset-4 transition-colors hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
            href={siteConfig.links.github}
            rel="noopener noreferrer"
            target="_blank"
          >
            Read the source
          </a>
        </li>
      </ul>
    </Container>
  </div>
);
