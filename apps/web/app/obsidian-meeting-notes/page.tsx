import type { Metadata } from "next";

import { MarkdownNoteMock } from "@/components/mocks/markdown-note-mock";
import { ObsidianMock } from "@/components/mocks/obsidian-mock";
import {
  ArticleBody,
  ArticleHeader,
  Bullet,
  Bullets,
  LINK,
  Lead,
  Prose,
} from "@/components/shared/article";
import { DownloadButton } from "@/components/shared/download-button";
import { JsonLd } from "@/components/shared/json-ld";
import { SiteFooter } from "@/components/shared/site-footer";
import { SiteHeader } from "@/components/shared/site-header";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { siteConfig } from "@/lib/config";
import { getLatestRelease } from "@/lib/release";
import { faqPageSchema } from "@/lib/structured-data";

export const metadata: Metadata = {
  alternates: { canonical: "/obsidian-meeting-notes" },
  description:
    "Record and transcribe your meetings straight into an Obsidian vault. Convene writes a Markdown note with YAML frontmatter, an action-item checklist, and timestamp citations that work as wikilinks.",
  openGraph: {
    description:
      "Record and transcribe meetings straight into an Obsidian vault, as Markdown you own.",
    title: "AI meeting notes in Obsidian",
    type: "article",
    url: "/obsidian-meeting-notes",
  },
  title: "AI meeting notes that write themselves into your Obsidian vault",
};

const FAQ = [
  {
    answer:
      "Convene asks you to pick a folder the first time you run it. Choose your vault, or a folder inside it such as Work/Meetings. From then on every meeting is saved there as a Markdown file the moment you stop recording, and Obsidian picks it up on its next scan — usually instantly.",
    question: "How do I save meeting notes into my Obsidian vault?",
  },
  {
    answer:
      "A single .md file named like “2026-06-09 103128 - Standup - a1b2c3d4.md”. It opens with YAML frontmatter — title, date, duration, attendees, and which model wrote the summary — then a Key Moments index, a TL;DR, decisions, an action-item checklist, and the full transcript under timestamped headings.",
    question: "What does the note look like?",
  },
  {
    answer:
      "Yes. The frontmatter includes a tags list with meeting and convene, plus attendees, date and duration_minutes as real fields. Dataview and Bases can query all of it, so a table of every meeting Sarah attended this month is a few lines away.",
    question: "Does it work with Dataview and Obsidian Bases?",
  },
  {
    answer:
      "They are real wikilinks. When the summary says a decision was made at 00:38, that timestamp is written as a link to the ### 00:38 heading in the transcript below it, so one click takes you to what was actually said. Convene computes the transcript headings before it writes the summary, so a citation can never point at a heading that does not exist.",
    question: "Do the timestamp citations actually link to anything?",
  },
  {
    answer:
      "It handles it properly. Vaults synced through iCloud Drive are the common case, so Convene writes through the system file coordinator rather than dropping bytes on the path. That is what stops you ending up with “conflicted copy” files or a half-synced note.",
    question: "Will it break my iCloud-synced vault?",
  },
  {
    answer:
      "Point both at the same vault. There is no Convene account and no sync service — the Mac app and the iPhone app each write Markdown into the folder you gave them, and whatever already syncs your vault carries the files between devices.",
    question: "Can the Mac and iPhone apps write into the same vault?",
  },
  {
    answer:
      "Only the note. The structured transcript JSON is kept in Application Support, deliberately outside your vault, so Convene never litters your graph with files you did not ask for. Audio is never written to disk at all.",
    question: "Does it put anything else in my vault?",
  },
];

export default async function ObsidianMeetingNotesPage() {
  const release = await getLatestRelease();

  return (
    <div className="flex min-h-dvh flex-col">
      <JsonLd data={faqPageSchema(FAQ)} />
      <SiteHeader downloadUrl={release.downloadUrl} />

      <main className="flex-1 pt-14" id="main">
        <ArticleHeader
          lede="Convene records the call, transcribes both sides live, and writes the finished note straight into your vault as Markdown. No export step, no plugin, and no second app holding your notes hostage."
          title="AI meeting notes that write themselves into your Obsidian vault"
          width="max-w-3xl"
        />

        <ArticleBody width="max-w-3xl">
          <Prose title="The problem with every other option">
            <p>
              Granola, Otter, Fireflies, Notion — they all store your meeting
              notes inside their own product. You can usually export, which
              means you can usually do a chore. The notes you want to link to
              your project page, your 1:1 note and your reading list end up
              somewhere your vault cannot see.
            </p>
            <p>
              Convene inverts that. <Lead>The file is the product.</Lead> It
              appears in your vault the moment you stop recording, already
              formatted, already tagged, already linked.
            </p>
          </Prose>

          <Prose title="What lands in your vault">
            <p>
              One Markdown file per meeting, with frontmatter Dataview can query
              and a body you would not be embarrassed to have written yourself.
            </p>
            <MarkdownNoteMock className="mt-6" />
          </Prose>

          <Prose title="Citations that actually go somewhere">
            <p>
              The summary is only allowed to cite timestamps that exist in the
              transcript, and each one is written as a wikilink to the heading
              Convene emitted for that moment. So “decided at 00:38” is one
              click away from the sentence where it was decided.
            </p>
            <p>
              The same is true of key moments: press{" "}
              <span className="whitespace-nowrap font-medium text-foreground">
                ⌥⇧K
              </span>{" "}
              during a call and the flag lands twice — in an index at the top of
              the note, and inline in the transcript at the right second.
            </p>
            <ObsidianMock className="mt-6" />
          </Prose>

          <Prose title="Setting it up">
            <Bullets>
              <Bullet>
                <Lead>Install Convene and open Settings.</Lead> Under General,
                choose your save folder. Pick the vault itself, or a subfolder
                like{" "}
                <code className="rounded bg-secondary px-1.5 py-0.5 font-mono text-[0.85em] text-foreground">
                  Work/Meetings
                </code>{" "}
                if you would rather keep them together.
              </Bullet>
              <Bullet>
                <Lead>Add an AssemblyAI key.</Lead> Transcription runs on your
                own key, billed to you directly.{" "}
                <a
                  className={LINK}
                  href={siteConfig.links.assemblyai}
                  rel="noopener noreferrer"
                  target="_blank"
                >
                  Create one here
                </a>
                .
              </Bullet>
              <Bullet>
                <Lead>Optionally add an Anthropic or OpenAI key</Lead> for
                summaries. Without one you still get the transcript, the key
                moments and the note — just no TL;DR.
              </Bullet>
              <Bullet>
                <Lead>Record a meeting.</Lead> The file appears in the vault
                when you stop. The summary arrives a moment later and rewrites
                the note in place.
              </Bullet>
            </Bullets>
          </Prose>

          <Prose title="Querying your meetings">
            <p>
              Because the frontmatter is real structured data —{" "}
              <code className="font-mono text-[0.9em]">attendees</code>,{" "}
              <code className="font-mono text-[0.9em]">date</code>,{" "}
              <code className="font-mono text-[0.9em]">duration_minutes</code>,{" "}
              <code className="font-mono text-[0.9em]">tags</code> — Dataview
              and Bases can treat your meetings as a table. Every call with a
              given person this quarter, every meeting over an hour, every note
              still carrying unchecked action items: all of it is a query rather
              than a search.
            </p>
          </Prose>

          <Prose title="Syncing between your Mac and your phone">
            <p>
              There is no Convene account, no CloudKit and no sync service. Both
              apps write into the folder you chose, so if that folder is a vault
              synced by iCloud, Obsidian Sync, Syncthing or git, your meeting
              notes travel the same way the rest of your vault already does.
            </p>
            <p>
              Convene writes through the system file coordinator specifically
              because synced vaults are the normal case — that is what keeps a
              note from landing half-written and turning into a conflicted copy.
            </p>
          </Prose>

          <Prose id="faq" title="Questions">
            <Accordion className="w-full" collapsible type="single">
              {FAQ.map((item) => (
                <AccordionItem key={item.question} value={item.question}>
                  <AccordionTrigger>{item.question}</AccordionTrigger>
                  <AccordionContent>{item.answer}</AccordionContent>
                </AccordionItem>
              ))}
            </Accordion>
          </Prose>

          <div className="mt-14 rounded-xl bg-card p-6 sm:p-8">
            <h2 className="font-display font-light text-2xl tracking-tight">
              Point it at your vault
            </h2>
            <p className="mt-3 max-w-[52ch] text-muted-foreground leading-relaxed">
              Free, MIT licensed, no account. The next meeting you take will be
              a note in your vault before you have closed the tab.
            </p>
            <DownloadButton
              className="mt-6"
              href={release.downloadUrl}
              placement="obsidian-meeting-notes"
            />
            <p className="mt-3 text-muted-foreground text-sm">
              {release.version} · {siteConfig.requirements.macos}
              {release.fileSize ? ` · ${release.fileSize}` : ""}
            </p>
          </div>
        </ArticleBody>
      </main>

      <SiteFooter />
    </div>
  );
}
