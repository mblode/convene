import { generateOgImage } from "./og-image-shared";

export { contentType, size } from "./og-image-shared";

export const alt = "Convene: your meetings, as Markdown in your own folder.";

export const runtime = "nodejs";

export default function Image() {
  return generateOgImage();
}
