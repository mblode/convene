import { generateOgImage } from "./og-image-shared";

export { contentType, size } from "./og-image-shared";

export const alt = "Convene: your meetings, as Markdown in your own folder.";

// The shared generator reads the Glide TTF cuts off disk, which the edge
// runtime cannot do.
export const runtime = "nodejs";

// Near-identical to `twitter-image.tsx` on purpose: Next's file conventions
// want a route per card, and both cards are one design, so the shared generator
// is the single source and a change lands on both. This route used to render
// its own gradient and pass no `fonts` at all, which meant every non-Twitter
// share went out in Satori's bundled fallback face on a site that loads Glide
// everywhere else.
export default function Image() {
  return generateOgImage();
}
