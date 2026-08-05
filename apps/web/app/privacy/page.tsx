import type { Metadata } from "next";

import {
  Code,
  DocItem,
  DocList,
  DocPage,
  DocSection,
  LINK,
} from "@/components/doc-page";
import { siteConfig } from "@/lib/config";

const description =
  "Convene has no account and no server. What the Mac and iPhone apps do with your meeting data, which services see it, and what stays on your device.";

export const metadata: Metadata = {
  alternates: { canonical: "/privacy" },
  description,
  openGraph: {
    description,
    title: "Privacy",
    type: "article",
  },
  title: "Privacy",
};

export default function PrivacyPage() {
  return (
    <DocPage
      intro="Convene has no account and no server of its own. This page sets out what the Mac and iPhone apps do with your meeting data, and which services see it."
      meta="Last updated 5 August 2026"
      title="Privacy"
    >
      <DocSection title="The short version">
        <DocList>
          <DocItem>
            There is no Convene account and no Convene server. Matthew Blode,
            who makes Convene, receives no data from either app.
          </DocItem>
          <DocItem>
            Neither app contains analytics, telemetry, or crash reporting.
          </DocItem>
          <DocItem>
            Your API keys are your own. They are stored in your device&rsquo;s
            Keychain, and each key is sent only to the service it belongs to.
          </DocItem>
          <DocItem>
            While a meeting records, audio goes to AssemblyAI under your own
            account. If summaries are on, the transcript goes to Anthropic or
            OpenAI under your own key.
          </DocItem>
          <DocItem>
            Your notes are Markdown files on your device. Delete a meeting and
            the file is gone.
          </DocItem>
        </DocList>
      </DocSection>

      <DocSection title="What Convene collects">
        <p>
          Nothing. There is no sign-up, no licence check, and no Convene
          endpoint for anything to arrive at. The apps talk to the transcription
          and summary services you configure, and — on the Mac — to GitHub to
          check for a new version. Those are the only network requests either
          app makes.
        </p>
        <p>
          Convene is MIT licensed and the source is public, so this is something
          you can check rather than take on trust.{" "}
          <a
            className={LINK}
            href={siteConfig.links.github}
            rel="noopener noreferrer"
            target="_blank"
          >
            Read the source
          </a>
          .
        </p>
      </DocSection>

      <DocSection title="What leaves your device">
        <p>
          Two things leave, and both go to services you hold the account for.
        </p>
        <DocList>
          <DocItem>
            <span className="text-polar-white">
              Audio, while a meeting is recording.
            </span>{" "}
            It streams to AssemblyAI at{" "}
            <Code>wss://streaming.assemblyai.com/v3/ws</Code> using your
            AssemblyAI key, and comes back as text. Convene never writes an
            audio file: there is no recording left behind on your device or
            anywhere else.
          </DocItem>
          <DocItem>
            <span className="text-polar-white">
              The transcript, when a meeting ends, if summaries are on.
            </span>{" "}
            It goes to <Code>https://api.anthropic.com/v1/messages</Code> or{" "}
            <Code>https://api.openai.com/v1/responses</Code>, whichever provider
            you picked, using your own key. Summaries are optional: with no
            summary key saved nothing is sent and the meeting simply saves
            without one.
          </DocItem>
        </DocList>
      </DocSection>

      <DocSection title="The services you connect">
        <p>
          Convene sends your data to these services on your behalf, under your
          own account. Once it arrives, their privacy policy and their terms
          govern it, not this page.
        </p>
        <DocList>
          <DocItem>
            <a
              className={LINK}
              href="https://www.assemblyai.com/legal/privacy-policy"
              rel="noopener noreferrer"
              target="_blank"
            >
              AssemblyAI
            </a>{" "}
            transcribes your audio. Required — nothing can be transcribed
            without a key.
          </DocItem>
          <DocItem>
            <a
              className={LINK}
              href="https://www.anthropic.com/legal/privacy"
              rel="noopener noreferrer"
              target="_blank"
            >
              Anthropic
            </a>{" "}
            writes the summary if you choose Claude. Optional.
          </DocItem>
          <DocItem>
            <a
              className={LINK}
              href="https://openai.com/policies/privacy-policy"
              rel="noopener noreferrer"
              target="_blank"
            >
              OpenAI
            </a>{" "}
            writes the summary if you choose OpenAI. Optional.
          </DocItem>
        </DocList>
        <p>
          Each has its own position on how long it keeps data and what it does
          with it. Read theirs before you record something sensitive.
        </p>
      </DocSection>

      <DocSection title="Your API keys">
        <p>
          You create the keys in each provider&rsquo;s own dashboard and you can
          revoke them there. Convene stores each one in your device&rsquo;s
          Keychain and sends it only to the service it belongs to: your
          AssemblyAI key never goes to Anthropic, and your Anthropic key never
          goes to AssemblyAI.
        </p>
      </DocSection>

      <DocSection title="Where your meetings are stored">
        <DocList>
          <DocItem>
            The note is a Markdown file. On iPhone it saves to Convene&rsquo;s
            own folder — Files &rsaquo; On My iPhone &rsaquo; Convene — or to a
            folder you pick, such as an Obsidian vault. On the Mac it saves to
            the folder you pick.
          </DocItem>
          <DocItem>
            While a meeting runs, the transcript is appended to a recovery log
            in the app&rsquo;s own storage, so a crash cannot lose it. The log
            is deleted once the note is saved.
          </DocItem>
          <DocItem>
            Convene uploads and backs up nothing. Your notes sync only if the
            folder you chose already syncs, iCloud Drive being the usual case.
          </DocItem>
        </DocList>
      </DocSection>

      <DocSection title="Permissions">
        <p>
          <span className="text-polar-white">On iPhone,</span> the microphone is
          the only permission the app asks for, and it is used only while
          recording. iOS asks the first time you record. Recording keeps going
          when the screen locks, which is the audio background mode rather than
          a second permission.
        </p>
        <p>
          <span className="text-polar-white">On the Mac,</span> the app is
          sandboxed and asks for:
        </p>
        <DocList>
          <DocItem>The microphone, to capture your side of the call.</DocItem>
          <DocItem>
            System audio recording, to capture the other side. Audio only: no
            video and no picture of your screen is captured.
          </DocItem>
          <DocItem>
            Your calendar, to show today&rsquo;s events and title a meeting.
            Convene reads events and never writes them, and what it reads stays
            on your Mac.
          </DocItem>
          <DocItem>
            Notifications, for the prompt that offers to record when a meeting
            app opens.
          </DocItem>
          <DocItem>
            Apple events, to notice when Zoom, Meet, Teams, Webex, or BlueJeans
            is running.
          </DocItem>
          <DocItem>
            Files: the folder you pick for your notes, and nothing else. The
            sandbox gives it access to nothing you have not chosen.
          </DocItem>
        </DocList>
      </DocSection>

      <DocSection title="Software updates on the Mac">
        <p>
          The Mac app checks for new versions with Sparkle, which fetches a
          signed appcast file from GitHub. Like any web request, that lets
          GitHub see your IP address. Nothing about you or your meetings is
          sent.
        </p>
      </DocSection>

      <DocSection title="This website">
        <p>
          This site uses PostHog to count page views and see which links get
          clicked. That is website analytics, and it is separate from the apps:
          neither the Mac app nor the iPhone app contains any analytics code.
        </p>
      </DocSection>

      <DocSection title="Changes">
        <p>
          If this policy changes, the date at the top changes with it. The page
          lives in the same public repository as the apps, so every revision is
          in the history.
        </p>
      </DocSection>

      <DocSection title="Contact">
        <p>
          Questions about any of this, email{" "}
          <a className={LINK} href="mailto:m.blode@gmail.com">
            m.blode@gmail.com
          </a>
          .
        </p>
      </DocSection>
    </DocPage>
  );
}
