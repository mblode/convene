import { Reveal } from "@/components/ui/reveal";
import { Container, Section, SectionHeading } from "@/components/ui/section";
import { PROOF_CLOSING, PROOF_ROWS, SECTIONS } from "@/lib/landing";
import type { Release } from "@/lib/release";

/**
 * Proof, as a list of things somebody can go and verify.
 *
 * This replaced `TrustStrip`, a row of four unlinked phrases, and that
 * component's reasoning is carried forward here because it still governs: only
 * claims a visitor could check for themselves, no star count, no user number,
 * no compliance badge — this audience punishes an unsourced figure harder than
 * it rewards one. The repository has one star; rendering "1" beside a download
 * button spends real credibility to say nothing.
 *
 * What the strip could not do was prove any of it. "Sandboxed and notarised" as
 * a bare phrase is indistinguishable from a badge. So every row now carries the
 * link a reader would check it with, and `keychainSource` and `walSource` —
 * which had been sitting in `siteConfig.links` pointing at real files that no
 * page linked to — finally do their job.
 *
 * The release row is separate from the static rows because it is the only fact
 * here that changes on its own, and it degrades honestly: when the GitHub API
 * is rate-limited `getLatestRelease` returns the real shipped version with no
 * size and no date, and this renders the version alone rather than inventing
 * the rest.
 */
/**
 * "Check it" rather than the file name: the row already said what the claim is,
 * so the visible link only has to say that checking it is possible.
 *
 * The `aria-label` is not decoration. Seven rows means seven links whose visible
 * text is identical, and a screen-reader user pulling up a list of links on this
 * page would get "Check it" seven times with nothing to choose between. The
 * label restores each row's own subject to the accessible name while the visible
 * text stays short enough not to break the sentence it sits in.
 */
const FactLink = ({ href, term }: { href: string; term: string }) => (
  <a
    aria-label={`Check it: ${term.toLowerCase()}`}
    className="whitespace-nowrap rounded text-link underline decoration-link/30 underline-offset-4 transition-colors hover:decoration-link focus-visible:ring-3 focus-visible:ring-ring focus-visible:outline-none"
    href={href}
    rel="noopener noreferrer"
    target="_blank"
  >
    Check it
  </a>
);

export const FactList = ({ release }: { release: Release }) => {
  const releaseDetail = [
    release.version,
    release.fileSize,
    release.publishedRelative,
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <Section className="border-border/60 border-t" id="proof">
      <Container>
        <Reveal>
          <SectionHeading eyebrow="Proof">
            {SECTIONS.proof.heading}
          </SectionHeading>

          <dl className="mt-8 divide-y divide-border/60 border-border/60 border-t">
            <div className="grid gap-1 py-4 sm:grid-cols-[minmax(0,11rem)_minmax(0,1fr)] sm:gap-6">
              <dt className="font-medium text-sm">Latest release</dt>
              <dd className="text-pretty text-muted-foreground text-sm">
                <span className="tabular-nums">{releaseDetail}</span>{" "}
                <FactLink href={release.downloadUrl} term="Latest release" />
              </dd>
            </div>

            {PROOF_ROWS.map((fact) => (
              <div
                className="grid gap-1 py-4 sm:grid-cols-[minmax(0,11rem)_minmax(0,1fr)] sm:gap-6"
                key={fact.term}
              >
                <dt className="font-medium text-sm">{fact.term}</dt>
                <dd className="text-pretty text-muted-foreground text-sm">
                  {fact.detail} <FactLink href={fact.href} term={fact.term} />
                </dd>
              </div>
            ))}
          </dl>

          <p className="mt-6 max-w-[60ch] text-pretty text-muted-foreground text-sm">
            {PROOF_CLOSING}
          </p>
        </Reveal>
      </Container>
    </Section>
  );
};
