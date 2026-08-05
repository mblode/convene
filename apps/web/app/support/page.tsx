import type { Metadata } from "next";

import {
  DocHeading,
  DocItem,
  DocList,
  DocPage,
  DocSection,
  LINK,
} from "@/components/doc-page";
import { siteConfig } from "@/lib/config";

const description =
  "Getting Convene running on iPhone and Mac: what you need, where your notes are saved, what to do when transcription, the microphone, or your vault folder stops working, and how to get in touch.";

export const metadata: Metadata = {
  alternates: { canonical: "/support" },
  description,
  openGraph: {
    description,
    title: "Support — Convene",
    type: "article",
  },
  title: "Support",
};

export default function SupportPage() {
  return (
    <DocPage
      intro="How to get Convene recording, where your notes end up, and what to do when something stops working."
      title="Support"
    >
      <DocSection title="What you need">
        <DocList>
          <DocItem>The iPhone app needs iOS 17 or later.</DocItem>
          <DocItem>The Mac app needs macOS 15 (Sequoia) or later.</DocItem>
          <DocItem>
            An{" "}
            <a
              className={LINK}
              href="https://www.assemblyai.com/dashboard/api-keys"
              rel="noopener noreferrer"
              target="_blank"
            >
              AssemblyAI key
            </a>
            , which does the transcription. This one is required.
          </DocItem>
          <DocItem>
            Optionally an{" "}
            <a
              className={LINK}
              href="https://console.anthropic.com/settings/keys"
              rel="noopener noreferrer"
              target="_blank"
            >
              Anthropic
            </a>{" "}
            or{" "}
            <a
              className={LINK}
              href="https://platform.openai.com/api-keys"
              rel="noopener noreferrer"
              target="_blank"
            >
              OpenAI
            </a>{" "}
            key, which powers the summary and nothing else. Claude writes the
            better ones.
          </DocItem>
        </DocList>
        <p>
          The keys are yours. They are stored in your device&rsquo;s Keychain
          and you pay each provider directly, because there is no Convene server
          in between. A Claude Pro or ChatGPT Plus subscription does not include
          API access — that is billed separately, and it catches almost everyone
          out.
        </p>
      </DocSection>

      <DocSection title="Getting started">
        <p>On iPhone:</p>
        <DocList>
          <DocItem>
            Open Settings and paste your AssemblyAI key under API keys. The
            setup card on the main screen links straight to it, and tapping
            record without a key opens the same sheet.
          </DocItem>
          <DocItem>
            Tap record. iOS asks for the microphone the first time, and only the
            first time.
          </DocItem>
          <DocItem>
            Optionally, tap{" "}
            <span className="text-polar-white">Choose your vault</span> in
            Settings and browse to your Obsidian vault or any folder in iCloud
            Drive. Leave it alone and meetings stay in Convene&rsquo;s own
            folder.
          </DocItem>
        </DocList>
        <p>
          On the Mac, first launch asks for Microphone, Screen Recording (audio
          only, no video), Calendar, and Notifications, then you pick the folder
          your notes are written to. Keys go in Settings, the same as on iPhone.
        </p>
      </DocSection>

      <DocSection title="Where your notes are">
        <p>
          Every meeting is a Markdown file, written the moment you stop. On
          iPhone, unless you have picked a folder, that file is in the Files app
          under{" "}
          <span className="text-polar-white">
            On My iPhone &rsaquo; Convene
          </span>
          . On the Mac it is in the folder you chose.
        </p>
        <p>
          Point either app at an Obsidian vault and the notes are simply files
          in that vault, syncing wherever the vault already syncs.
        </p>
      </DocSection>

      <DocSection title="When something goes wrong">
        <DocHeading>
          Nothing gets transcribed, or tapping record opens a key sheet
        </DocHeading>
        <p>
          There is no AssemblyAI key saved. Convene transcribes through
          AssemblyAI, so it cannot hear anything without one. Add it in
          Settings, or from the setup card on the main screen.
        </p>

        <DocHeading>Microphone access is off for Convene</DocHeading>
        <p>
          The microphone permission was denied. iOS raises that prompt once and
          never again, so the only way back is iPhone Settings &rsaquo; Convene
          &rsaquo; Microphone. Convene&rsquo;s own Settings screen has a link
          straight there. If it says &ldquo;Not yet asked&rdquo;, there is
          nothing to do — iOS asks the first time you record.
        </p>

        <DocHeading>Convene can&rsquo;t reach that folder right now</DocHeading>
        <p>
          The folder you chose has been renamed, moved, or signed out of iCloud.
          Meetings are not lost: they save to Convene&rsquo;s own folder on the
          iPhone until you choose the vault again in Settings. If the folder is
          gone for good, switching back to the Convene folder on this iPhone
          clears it and stops the warning.
        </p>

        <DocHeading>Meetings save without a summary</DocHeading>
        <p>
          Summaries need their own key, separate from the transcription key.
          Check that the provider selected in Settings is the one whose key you
          saved: with Claude selected, an OpenAI key does nothing.
        </p>
      </DocSection>

      <DocSection title="Reporting a bug">
        <p>
          Open an issue at{" "}
          <a
            className={LINK}
            href={`${siteConfig.links.github}/issues`}
            rel="noopener noreferrer"
            target="_blank"
          >
            github.com/mblode/convene/issues
          </a>
          . The version number in Settings &rsaquo; About and what you were
          doing at the time are usually enough to go on.
        </p>
      </DocSection>

      <DocSection title="Contact">
        <p>
          Anything else, email{" "}
          <a className={LINK} href="mailto:m.blode@gmail.com">
            m.blode@gmail.com
          </a>
          .
        </p>
      </DocSection>
    </DocPage>
  );
}
