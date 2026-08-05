import Link from "next/link";

import { asset, siteConfig } from "@/lib/config";

const COLUMNS = [
  {
    links: [
      { href: "/#how-it-works", label: "How it works" },
      { href: "/#features", label: "Features" },
      { href: "/#setup", label: "Setup" },
      { href: "/#iphone", label: "iPhone" },
      { href: "/#faq", label: "FAQ" },
    ],
    title: "Product",
  },
  {
    links: [
      { href: "/granola-alternative", label: "Granola alternative" },
      { href: "/obsidian-meeting-notes", label: "Obsidian meeting notes" },
    ],
    title: "Compare",
  },
  {
    external: true,
    links: [
      { href: siteConfig.links.github, label: "Source on GitHub" },
      { href: siteConfig.links.releases, label: "Releases" },
      // The repo has no LICENSE file; the README's License section is the
      // canonical statement. Point there until one is added.
      { href: `${siteConfig.links.github}#license`, label: "MIT license" },
    ],
    title: "Open source",
  },
] as const;

export const SiteFooter = () => (
  <footer className="border-border/60 border-t">
    <div className="mx-auto w-full max-w-5xl px-4 py-14 sm:px-6">
      <div className="grid gap-10 lg:grid-cols-[1.4fr_repeat(3,1fr)]">
        <div>
          <p className="font-medium text-[15px]">Convene</p>
          <p className="mt-2 max-w-[34ch] text-muted-foreground text-sm leading-relaxed">
            Meeting notes that end up as Markdown in a folder you own. Open
            source, MIT licensed.
          </p>
        </div>

        {COLUMNS.map((column) => (
          <nav aria-label={column.title} key={column.title}>
            <p className="font-medium text-sm">{column.title}</p>
            <ul className="mt-3 space-y-2">
              {column.links.map((link) => (
                <li key={link.href}>
                  {"external" in column && column.external ? (
                    <a
                      className="rounded text-muted-foreground text-sm transition-colors hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
                      href={link.href}
                      rel="noopener noreferrer"
                      target="_blank"
                    >
                      {link.label}
                    </a>
                  ) : (
                    <Link
                      className="rounded text-muted-foreground text-sm transition-colors hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
                      href={link.href}
                    >
                      {link.label}
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          </nav>
        ))}
      </div>

      <div className="mt-12 flex flex-col items-center justify-between gap-3 border-border/60 border-t pt-6 text-sm sm:flex-row">
        <p className="flex items-center gap-1 text-muted-foreground">
          Crafted by
          <a
            className="flex items-center gap-2 rounded-full py-1 pr-2 pl-1 transition-colors hover:text-foreground"
            href={siteConfig.links.author}
            rel="author noopener noreferrer"
            target="_blank"
          >
            {/* oxlint-disable-next-line nextjs/no-img-element -- self-hosted 20px avatar, plain img avoids next/image overhead */}
            <img
              alt=""
              className="rounded-full"
              height={20}
              loading="lazy"
              src={asset("/avatar-sm.png")}
              width={20}
            />
            Matthew Blode
          </a>
        </p>
        <nav aria-label="Legal and support" className="flex items-center gap-4">
          <Link
            className="rounded text-muted-foreground transition-colors hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
            href="/support"
          >
            Support
          </Link>
          <Link
            className="rounded text-muted-foreground transition-colors hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
            href="/privacy"
          >
            Privacy
          </Link>
        </nav>

        <p className="text-muted-foreground">
          MIT licensed · No tracking in the app
        </p>
      </div>
    </div>
  </footer>
);
