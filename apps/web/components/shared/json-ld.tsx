// oxlint-disable react/no-danger -- ld+json has to reach the crawler as a raw
// string; React would escape it as text children. The payload is ours, never
// user input, so there is nothing to inject.

export const JsonLd = ({ data }: { data: Record<string, unknown> }) => (
  <script
    dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    type="application/ld+json"
  />
);
