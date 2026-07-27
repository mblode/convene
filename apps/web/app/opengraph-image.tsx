import { ImageResponse } from "next/og";

export const alt = "Convene - open-source AI meeting notes for macOS";
export const contentType = "image/png";
export const size = { height: 630, width: 1200 };

// Design tokens mirrored from globals.css.
const SKY =
  "linear-gradient(180deg, rgb(90, 118, 148) 0%, rgb(126, 150, 168) 47%, rgb(171, 183, 181) 100%)";
const POLAR_WHITE = "#ffffff";

// Glide is a variable WOFF2 font, which next/og (Satori) cannot decode, so we
// fall back to the bundled default font.
export default function OpengraphImage() {
  return new ImageResponse(
    <div
      style={{
        alignItems: "center",
        background: SKY,
        display: "flex",
        flexDirection: "column",
        height: "100%",
        justifyContent: "center",
        padding: "80px",
        width: "100%",
      }}
    >
      <div
        style={{
          color: POLAR_WHITE,
          display: "flex",
          fontSize: 148,
          fontWeight: 500,
          letterSpacing: "-0.04em",
          lineHeight: 1,
        }}
      >
        Convene
      </div>
      <div
        style={{
          color: "rgba(255, 255, 255, 0.85)",
          display: "flex",
          fontSize: 46,
          marginTop: 28,
        }}
      >
        An open-source Granola clone for macOS.
      </div>
      <div
        style={{
          color: "rgba(255, 255, 255, 0.7)",
          display: "flex",
          fontSize: 30,
          marginTop: 20,
          textAlign: "center",
        }}
      >
        Records, transcribes, and writes notes into a folder you own.
      </div>
    </div>,
    { ...size }
  );
}
