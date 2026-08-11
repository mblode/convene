export interface FaqItem {
  answer: string;
  /**
   * Anchor slug, rendered as the `id` on the question's own `<h3>` and
   * published as `acceptedAnswer.url`. Hand-written rather than derived from
   * the question text, so rewording a question cannot silently break an
   * inbound link.
   */
  id: string;
  question: string;
}

/** One source for the rendered FAQ and FAQPage data. The remaining questions
 * cover API subscriptions and recording consent; the page answers the rest. */
export const FAQ: FaqItem[] = [
  {
    answer:
      "No. A Claude Pro or ChatGPT Plus subscription covers the chat apps, not API access, which is billed separately. You need a key from console.anthropic.com or platform.openai.com. This catches almost everyone.",
    id: "subscription-keys",
    question: "Will my Claude or ChatGPT subscription work for summaries?",
  },
  {
    answer:
      "Convene does not announce itself, so nobody is told for you. Recording-consent law varies by country and by state, and some of it applies to you rather than the software. Say that you are recording.",
    id: "consent",
    question: "Do I need to tell people I am recording?",
  },
];
