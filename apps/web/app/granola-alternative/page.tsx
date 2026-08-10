import type { Metadata } from "next";
import Link from "next/link";

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
import { ogImages, ogSiteName, siteConfig } from "@/lib/config";
import { getLatestRelease } from "@/lib/release";
import { faqPageSchema } from "@/lib/structured-data";

const COMPARED_ON = "5 August 2026";

export const metadata: Metadata = {
  alternates: { canonical: "/granola-alternative" },
  description:
    "Convene is the open-source Granola alternative that writes meeting notes as Markdown into your own folder. An honest comparison: what Convene does better, what Granola does better, and how to choose.",
  openGraph: {
    description:
      "An honest comparison of Convene and Granola, including what Granola does better.",
    images: ogImages,
    siteName: ogSiteName,
    title: "The open-source Granola alternative",
    type: "article",
    url: "/granola-alternative",
  },
  title:
    "The open-source Granola alternative that saves notes to your own folder",
};

/** A real <table>, not a grid of divs: answer engines quote table rows and
 * skip CSS grids, and this page exists to be quoted. */
const ROWS = [
  {
    convene: "Open source, MIT",
    granola: "Closed source",
    label: "Source code",
  },
  {
    convene: "Markdown files in a folder you pick",
    granola: "In Granola's app and on its servers",
    label: "Where notes live",
  },
  {
    convene: "None — no account exists",
    granola: "Required",
    label: "Account",
  },
  {
    convene:
      "Free. You pay AssemblyAI and, optionally, Anthropic or OpenAI directly",
    granola: "Free tier, then a paid plan per user",
    label: "Price",
  },
  { convene: "No", granola: "No", label: "Bot joins the call" },
  {
    convene: "Two streams — your mic and system audio captured separately",
    granola: "System audio",
    label: "How it captures",
  },
  {
    convene: "Cloud, via your own AssemblyAI key",
    granola: "Cloud, via Granola",
    label: "Transcription",
  },
  {
    convene: "Your own Anthropic or OpenAI key, optional",
    granola: "Included",
    label: "AI summaries",
  },
  { convene: "macOS 15+", granola: "macOS and Windows", label: "Desktop" },
  {
    convene: "iPhone app, not yet on the App Store",
    granola: "iOS and Android, on the stores",
    label: "Mobile",
  },
  {
    convene: "Writes directly into your vault",
    granola: "Not natively",
    label: "Obsidian",
  },
  {
    convene: "None — it writes files, so use whatever reads files",
    granola: "Notion, Slack, HubSpot, Affinity, Zapier and more on paid plans",
    label: "Integrations",
  },
  {
    convene: "None",
    granola: "SSO and admin controls on Enterprise",
    label: "Team administration",
  },
];

const FAQ = [
  {
    answer:
      "Convene is open source and writes your notes as Markdown files into a folder you choose, usually an Obsidian vault. Granola is a commercial product that keeps your notes in its own app and on its servers. Neither sends a bot into your meeting. If you want to own the files, pick Convene; if you want a polished product with a team maintaining it, pick Granola.",
    question: "What is the difference between Convene and Granola?",
  },
  {
    answer:
      "Yes. Convene is MIT licensed and the source is on GitHub, so you can read exactly how it captures audio, where it sends it, and how it writes your notes.",
    question: "Is Convene really open source?",
  },
  {
    answer:
      "Convene itself is free forever. You pay AssemblyAI directly for transcription at their published rate, and Anthropic or OpenAI for summaries if you enable them. There is no markup, because there is no Convene server for the request to pass through. Whether that is cheaper than a Granola subscription depends on how many hours of meetings you record — check both providers' current pricing pages.",
    question: "Is Convene cheaper than Granola?",
  },
  {
    answer:
      "No, and this is the most important caveat. Convene streams your audio to AssemblyAI for transcription, using your own API key. What is different from Granola is that there is no Convene server in the path: the request goes from your Mac to AssemblyAI directly, and we never receive your audio, transcript or notes. If you need transcription that never leaves your machine, use a tool that runs a model locally.",
    question: "Does Convene keep my audio on my own machine?",
  },
  {
    answer:
      "Nothing to migrate, because Convene reads nothing. Old Granola notes stay in Granola; new meetings land in your folder as Markdown from the moment you install Convene. Granola can export, so you can move history across by hand if you want it in one place.",
    question: "Can I move my Granola notes to Convene?",
  },
  {
    answer:
      "Not for calls. Granola has iOS and Android apps on the stores. Convene's iPhone app is built but not yet released, and it works differently — it records the room through the phone's mic for in-person meetings, because iOS does not let an app capture another app's audio.",
    question: "Does Convene have a mobile app like Granola?",
  },
  {
    answer:
      "Convene has none, on purpose. It writes plain Markdown into a folder, so anything that reads files — Obsidian, ripgrep, git, your editor, an MCP server pointed at the folder — works without an integration. Granola has real integrations with Notion, Slack, HubSpot and others on paid plans. If you need a note pushed into a CRM automatically, Granola does that today and Convene does not.",
    question: "What integrations does Convene have?",
  },
];

export default async function GranolaAlternativePage() {
  const release = await getLatestRelease();

  return (
    <div className="flex min-h-dvh flex-col">
      <JsonLd data={faqPageSchema(FAQ)} />
      <SiteHeader downloadUrl={release.downloadUrl} />

      <main className="flex-1 pt-14" id="main">
        <ArticleHeader
          dateline={`Compared against Granola's public pricing page, help centre and product marketing as of ${COMPARED_ON}. Granola ships often — check their site before deciding.`}
          lede="Convene records both sides of your call, transcribes it live, and writes the note as a Markdown file into a folder you own. No bot joins the meeting, and there is no Convene server."
          title="Convene: the open-source Granola alternative that saves notes to your own folder"
          width="max-w-3xl"
        />

        <ArticleBody width="max-w-3xl">
          <Prose title="The short answer">
            <p>
              Granola and Convene solve the same problem the same way — capture
              the audio your computer is already playing, so nothing has to join
              the call and announce itself. They differ on one thing that turns
              out to matter a lot: <Lead>who ends up holding the notes.</Lead>
            </p>
            <p>
              Granola keeps them in Granola. Convene writes them into your
              folder as Markdown and then gets out of the way. That is the whole
              pitch, and it is also the whole trade-off: Convene has no
              integrations, no team administration, and no company behind it.
            </p>
          </Prose>

          <Prose title="Side by side" id="comparison">
            <div className="-mx-4 overflow-x-auto px-4 sm:mx-0 sm:px-0">
              <table className="w-full min-w-[38rem] border-collapse text-left text-sm">
                <caption className="sr-only">
                  Feature comparison of Convene and Granola as of {COMPARED_ON}
                </caption>
                <thead>
                  <tr className="border-border border-b">
                    <th
                      className="py-3 pr-4 font-medium text-foreground"
                      scope="col"
                    >
                      {" "}
                    </th>
                    <th
                      className="py-3 pr-4 font-medium text-foreground"
                      scope="col"
                    >
                      Convene
                    </th>
                    <th
                      className="py-3 font-medium text-foreground"
                      scope="col"
                    >
                      Granola
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {ROWS.map((row) => (
                    <tr
                      className="border-border/60 border-b align-top"
                      key={row.label}
                    >
                      <th
                        className="py-3 pr-4 font-medium text-foreground text-sm"
                        scope="row"
                      >
                        {row.label}
                      </th>
                      <td className="py-3 pr-4">{row.convene}</td>
                      <td className="py-3">{row.granola}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Prose>

          <Prose title="Choose Granola if…">
            <p>
              This is a genuine recommendation, not a straw man. Granola is a
              good product, and for a lot of people it is the right one.
            </p>
            <Bullets>
              <Bullet>
                <Lead>You want an iPhone app today.</Lead> Granola’s is on the
                App Store. Convene’s is built but not yet released, and when it
                arrives it will be aimed at in-person meetings rather than
                calls.
              </Bullet>
              <Bullet>
                <Lead>
                  You need notes to land in other tools automatically.
                </Lead>{" "}
                Notion, Slack, HubSpot, Affinity, Zapier. Convene writes a file
                and stops there.
              </Bullet>
              <Bullet>
                <Lead>You are buying for a team.</Lead> Granola has shared
                workspaces, SSO and admin controls. Convene has one user:
                whoever is sitting at the Mac.
              </Bullet>
              <Bullet>
                <Lead>You would rather pay someone than hold the keys.</Lead>{" "}
                Granola bills you once and handles transcription. Convene asks
                you to create an AssemblyAI key and pay them directly, which is
                more control and more setup.
              </Bullet>
              <Bullet>
                <Lead>You use Windows.</Lead> Convene is macOS only.
              </Bullet>
            </Bullets>
          </Prose>

          <Prose title="Choose Convene if…">
            <Bullets>
              <Bullet>
                <Lead>You want the notes to be files.</Lead> Markdown with YAML
                frontmatter, in a folder you picked, readable in ten years by
                anything. No export step, because there is nothing to export
                from.
              </Bullet>
              <Bullet>
                <Lead>You live in Obsidian.</Lead> Point Convene at the vault
                and the notes appear in it, with the summary’s timestamp
                citations as working wikilinks into the transcript.{" "}
                <Link className={LINK} href="/obsidian-meeting-notes">
                  More on the Obsidian setup
                </Link>
                .
              </Bullet>
              <Bullet>
                <Lead>You want to read the code.</Lead> Every claim on this site
                is checkable against the source rather than a policy page.
              </Bullet>
              <Bullet>
                <Lead>You would rather not have an account.</Lead> There is no
                sign-up, no licence check, and no server to sign up to.
              </Bullet>
              <Bullet>
                <Lead>
                  You want your side and their side kept apart properly.
                </Lead>{" "}
                Convene runs your mic and your Mac’s system audio as two
                separate transcription streams, so speaker attribution is
                structural rather than inferred.
              </Bullet>
            </Bullets>
          </Prose>

          <Prose title="The honest caveat">
            <p>
              Convene is not local transcription, and any page that tells you
              otherwise is selling something. Audio streams to AssemblyAI, and
              summaries go to Anthropic or OpenAI — both over keys you create
              and pay for yourself.
            </p>
            <p>
              What is true is narrower and, for most people, more useful:{" "}
              <Lead>there is no Convene server.</Lead> Nothing routes through us
              because there is nowhere for it to route. Your keys stay in your
              Keychain and your notes stay in your folder. If your requirement
              is that no audio ever leaves the machine, neither Convene nor
              Granola meets it — you want something running a model locally.
            </p>
          </Prose>

          <Prose id="faq" title="Granola alternative FAQ">
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
              Try it on one meeting
            </h2>
            <p className="mt-3 max-w-[52ch] text-muted-foreground leading-relaxed">
              Free and MIT licensed, with no account to create. Record one call
              and look at the file it leaves behind — that is really the whole
              decision.
            </p>
            <DownloadButton
              className="mt-6"
              href={release.downloadUrl}
              placement="granola-alternative"
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
