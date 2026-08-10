import { renderZoneOgImage } from "@/app/og-image-shared";
import { siteConfig } from "@/lib/config";

export {
  OG_CONTENT_TYPE as contentType,
  OG_SIZE as size,
} from "@/app/og-image-shared";

export const alt = "Convene: your meetings, as Markdown in your own folder.";

/**
 * The house card (Rule 12), replacing the cream Convene-only shared generator.
 *
 * The matching `twitter-image` is gone rather than converted: Next reuses this
 * route for `twitter:image`, and the old pair were the same design twice.
 */
export default function OpengraphImage() {
  return renderZoneOgImage({
    badge: "CONVENE",
    eyebrow: "blode.co/convene",
    subtitle: "Your meetings, as Markdown in your own folder.",
    title: siteConfig.name,
  });
}
