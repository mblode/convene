import { GoogleAnalytics } from "@next/third-parties/google";
import { Agentation } from "agentation";
import type { Metadata } from "next";
import localFont from "next/font/local";

import "./globals.css";

const glide = localFont({
  display: "swap",
  src: [
    { path: "../public/glide-variable.woff2", style: "normal" },
    { path: "../public/glide-variable-italic.woff2", style: "italic" },
  ],
  variable: "--font-glide",
  weight: "400 900",
});

export const metadata: Metadata = {
  appleWebApp: {
    title: "Convene",
  },
  description:
    "An open-source Granola clone for macOS. Records your meetings, transcribes them live, and writes the notes into a folder you own.",
  metadataBase: new URL("https://convene.blode.co"),
  openGraph: {
    description:
      "An open-source Granola clone for macOS. Records your meetings, transcribes them live, and writes the notes into a folder you own.",
    siteName: "Convene",
    title: "Convene",
  },
  title: "Convene",
  verification: {
    google: "mFwyBIbXTaKK4uF_NA0MzVWFyY40hPgBjFObg3rje04",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={glide.variable}>
      <body className="antialiased">
        {children}
        {process.env.NODE_ENV === "development" && <Agentation />}
      </body>
      <GoogleAnalytics gaId="G-NPZHV88NWJ" />
    </html>
  );
}
