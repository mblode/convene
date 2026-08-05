"use client";
"use no memo";

import { AnimatePresence, motion } from "motion/react";
import Image from "next/image";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";

import { Button } from "@/components/ui/button";
import { asset, siteConfig } from "@/lib/config";
import { cn } from "@/lib/utils";

const NAV = [
  { href: "/#how-it-works", label: "How it works" },
  { href: "/#features", label: "Features" },
  { href: "/#iphone", label: "iPhone" },
  { href: "/#faq", label: "FAQ" },
] as const;

export const SiteHeader = ({ downloadUrl }: { downloadUrl: string }) => {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const toggleRef = useRef<HTMLButtonElement | null>(null);

  useEffect(() => {
    let frame = 0;
    const onScroll = () => {
      // rAF-throttled: scroll fires far more often than the border changes.
      if (frame) {
        return;
      }
      frame = requestAnimationFrame(() => {
        setScrolled(window.scrollY > 50);
        frame = 0;
      });
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      if (frame) {
        cancelAnimationFrame(frame);
      }
    };
  }, []);

  useEffect(() => {
    if (!open) {
      return;
    }
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        toggleRef.current?.focus();
      }
    };
    // Close on resize past the breakpoint, so the overlay can't be left open
    // behind a desktop layout.
    const desktop = window.matchMedia("(min-width: 768px)");
    const onChange = () => desktop.matches && setOpen(false);

    document.addEventListener("keydown", onKeyDown);
    desktop.addEventListener("change", onChange);
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKeyDown);
      desktop.removeEventListener("change", onChange);
      document.body.style.overflow = "";
    };
  }, [open]);

  return (
    <header
      className={cn(
        "fixed inset-x-0 top-0 z-40 border-transparent border-b bg-background/80 backdrop-blur-lg transition-colors duration-200",
        scrolled && "border-border/60"
      )}
    >
      <div className="mx-auto flex h-14 w-full max-w-5xl items-center justify-between gap-4 px-4 sm:px-6">
        <Link
          className="flex items-center gap-2.5 rounded-md focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
          href="/"
        >
          <Image
            alt=""
            className="rounded-[22%]"
            height={24}
            priority
            src={asset("/app-icon.png")}
            width={24}
          />
          <span className="font-medium text-[15px] tracking-tight">
            Convene
          </span>
        </Link>

        <nav aria-label="Main" className="hidden items-center gap-6 md:flex">
          {NAV.map((item) => (
            <Link
              className="rounded-md text-muted-foreground text-sm transition-colors hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
              href={item.href}
              key={item.href}
            >
              {item.label}
            </Link>
          ))}
          <a
            className="rounded-md text-muted-foreground text-sm transition-colors hover:text-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
            href={siteConfig.links.github}
            rel="noreferrer"
            target="_blank"
          >
            GitHub
          </a>
        </nav>

        <div className="flex items-center gap-2">
          <Button
            className="hidden sm:inline-flex"
            render={<a href={downloadUrl}>Download for macOS</a>}
            size="sm"
          />
          <button
            aria-expanded={open}
            aria-label={open ? "Close menu" : "Open menu"}
            className="-mr-1 inline-flex size-9 items-center justify-center rounded-lg text-foreground transition-colors hover:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none md:hidden"
            onClick={() => setOpen((value) => !value)}
            ref={toggleRef}
            type="button"
          >
            {/* Each path carries its closed-state `d` as a real attribute, so
                the icon is correct on the server and before motion takes over —
                animating from an absent value renders an invalid path. */}
            <svg
              aria-hidden="true"
              fill="none"
              height="16"
              viewBox="0 0 16 16"
              width="16"
            >
              <motion.path
                animate={{ d: open ? "M3.5 3.5 L12.5 12.5" : "M2 4.5 L14 4.5" }}
                d="M2 4.5 L14 4.5"
                initial={false}
                stroke="currentColor"
                strokeLinecap="round"
                strokeWidth="1.5"
                transition={{ duration: 0.2 }}
              />
              <motion.path
                animate={{ opacity: open ? 0 : 1 }}
                d="M2 8 L14 8"
                initial={{ opacity: 1 }}
                stroke="currentColor"
                strokeLinecap="round"
                strokeWidth="1.5"
                transition={{ duration: 0.15 }}
              />
              <motion.path
                animate={{
                  d: open ? "M3.5 12.5 L12.5 3.5" : "M2 11.5 L14 11.5",
                }}
                d="M2 11.5 L14 11.5"
                initial={false}
                stroke="currentColor"
                strokeLinecap="round"
                strokeWidth="1.5"
                transition={{ duration: 0.2 }}
              />
            </svg>
          </button>
        </div>
      </div>

      <AnimatePresence>
        {open ? (
          <motion.div
            animate={{ opacity: 1 }}
            className="border-border/60 border-t bg-background md:hidden"
            exit={{ opacity: 0 }}
            initial={{ opacity: 0 }}
            transition={{ duration: 0.15 }}
          >
            <nav
              aria-label="Mobile"
              className="flex flex-col px-4 py-3 sm:px-6"
            >
              {[...NAV, { href: siteConfig.links.github, label: "GitHub" }].map(
                (item) => (
                  <a
                    className="rounded-md py-2.5 text-base transition-colors hover:text-muted-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none"
                    href={item.href}
                    key={item.href}
                    onClick={() => setOpen(false)}
                  >
                    {item.label}
                  </a>
                )
              )}
              <Button
                className="mt-3 w-full sm:hidden"
                render={<a href={downloadUrl}>Download for macOS</a>}
                size="lg"
              />
            </nav>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </header>
  );
};
