import { readFile } from "node:fs/promises";
import path from "node:path";

import { ImageResponse } from "next/og";

export const size = { height: 630, width: 1200 };
export const contentType = "image/png";

// Static TTF cuts, not the variable WOFF2 the site ships: Satori decodes
// neither WOFF2 nor variable axes, and silently falls back to its bundled font.
export const generateOgImage = async (): Promise<ImageResponse> => {
  const publicDir = path.join(process.cwd(), "public");

  const [glide300, glide400] = await Promise.all([
    readFile(path.join(publicDir, "glide-300.ttf")),
    readFile(path.join(publicDir, "glide-400.ttf")),
  ]);

  return new ImageResponse(
    <div
      style={{
        backgroundColor: "#f7f7f4",
        display: "flex",
        flexDirection: "column",
        fontFamily: "Glide",
        height: "100%",
        width: "100%",
      }}
    >
      <div style={{ backgroundColor: "#007eed", height: 6, width: "100%" }} />

      <div
        style={{
          display: "flex",
          flex: 1,
          flexDirection: "column",
          justifyContent: "space-between",
          padding: 64,
        }}
      >
        <div
          style={{
            color: "#26251e",
            fontSize: 28,
            fontWeight: 400,
            letterSpacing: -0.5,
          }}
        >
          Convene
        </div>

        <div
          style={{
            color: "#26251e",
            fontSize: 68,
            fontWeight: 300,
            letterSpacing: -2,
            lineHeight: 1.1,
            maxWidth: 900,
          }}
        >
          Your meetings, as Markdown in your own folder.
        </div>

        <div
          style={{
            color: "#26251e99",
            fontSize: 24,
            fontWeight: 400,
          }}
        >
          Open source · No meeting bot · No Convene server · macOS and iPhone
        </div>
      </div>
    </div>,
    {
      ...size,
      fonts: [
        {
          data: glide300,
          name: "Glide",
          style: "normal" as const,
          weight: 300 as const,
        },
        {
          data: glide400,
          name: "Glide",
          style: "normal" as const,
          weight: 400 as const,
        },
      ],
    }
  );
};
