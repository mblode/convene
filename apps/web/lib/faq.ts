export interface FaqItem {
  answer: string;
  question: string;
}

/** One source for the rendered accordion and the FAQPage structured data, so
 * the two cannot drift. Nine questions, not sixteen: each one here either
 * blocks a download or prevents a support email. Every claim is traceable to
 * the Swift source. */
export const FAQ: FaqItem[] = [
  {
    answer:
      "No. Convene records the audio your Mac is already playing, plus your microphone. Nothing is invited to the call and nothing appears in the participant list. The other people see what they would see if you were taking notes by hand.",
    question: "Does a bot join my meeting?",
  },
  {
    answer:
      "Into a folder you pick, as a Markdown file with YAML frontmatter. Most people point it at an Obsidian vault. There is no library to export from: the note is a file on your disk the moment the meeting ends, and you can move, edit, sync or delete it like any other file.",
    question: "Where do my notes go?",
  },
  {
    answer:
      "Partly, and it is worth being exact. Capture, the crash log and the finished note stay on your Mac. Transcription does not: audio streams to AssemblyAI over your own key, and if you turn on summaries the transcript goes to Anthropic or OpenAI over your own key. What is true is that there is no Convene server in the middle. We never receive your audio, transcript or notes, because there is nowhere for them to arrive. If you need transcription that never leaves the machine, Convene is not the right tool.",
    question: "Is it private? Does my audio leave my Mac?",
  },
  {
    answer:
      "Because there is no Convene server to route it through. Your own key means you pay the provider directly at their price with no markup, and you can revoke it whenever you like. It also means we could not read your audio if we wanted to.",
    question: "Why do I need my own AssemblyAI key?",
  },
  {
    answer:
      "No. A Claude Pro or ChatGPT Plus subscription covers the chat apps, not API access, which is billed separately. You need a key from console.anthropic.com or platform.openai.com. This catches almost everyone, so check it before assuming summaries are broken.",
    question: "Will my Claude or ChatGPT subscription work for summaries?",
  },
  {
    answer:
      "Your microphone, Calendar, and the screen permission macOS uses for system audio. Convene asks for audio only and records no video. Notifications are optional, and only used to offer recording when a meeting app opens.",
    question: "Why does it need screen recording permission?",
  },
  {
    answer:
      "You lose about two seconds. Convene writes every confirmed transcript segment and key moment to an append-only log, flushed to disk as it goes. On the next launch it finds the unfinished meeting and turns the log into a normal note.",
    question: "What happens if my Mac crashes mid-meeting?",
  },
  {
    answer:
      "Granola is a polished commercial product with a team behind it, an App Store iPhone app, and integrations Convene does not have. It also stores your notes on its servers. Convene is the open-source option for people who want the notes to be files they own, with no account and no vendor in the middle. If you would rather pay someone to run it for you, Granola is good and you should use it.",
    question: "How is this different from Granola?",
  },
  {
    answer:
      "macOS 15 or later, on Apple Silicon or Intel. The iPhone app needs iOS 17. The Mac app is sandboxed, notarised by Apple, and updates itself through Sparkle.",
    question: "What are the system requirements?",
  },
];
