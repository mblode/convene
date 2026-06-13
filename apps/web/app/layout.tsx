import type { Metadata } from "next";
import localFont from "next/font/local";
import { Agentation } from "agentation";
import "./globals.css";

const glide = localFont({
  src: [
    { path: "../public/glide-variable.woff2", style: "normal" },
    { path: "../public/glide-variable-italic.woff2", style: "italic" },
  ],
  variable: "--font-glide",
  weight: "400 900",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Convene",
  description:
    "Transcribe meetings, instantly. BYO OpenAI API key — no subscription required.",
  metadataBase: new URL("https://convene.blode.co"),
  openGraph: {
    title: "Convene",
    description:
      "Transcribe meetings, instantly. BYO OpenAI API key — no subscription required.",
    siteName: "Convene",
  },
  appleWebApp: {
    title: "Convene",
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
    </html>
  );
}
