"use client";

import {
  Checkmark1Icon as CheckIcon,
  CopySimpleIcon as CopyIcon,
} from "blode-icons-react";
import { AnimatePresence, motion } from "motion/react";
import { useCallback, useState } from "react";

import { cn } from "@/lib/utils";

interface CopyButtonProps {
  className?: string;
  content: string;
  label?: string;
}

export const CopyButton = ({
  className,
  content,
  label = "command",
}: CopyButtonProps) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = useCallback(async () => {
    try {
      await navigator.clipboard.writeText(content);
      setCopied(true);
      setTimeout(() => setCopied(false), 3000);
    } catch {
      // Clipboard access can be denied (insecure origin, permissions policy).
      // There is nothing useful to recover to, so leave the idle state alone.
    }
  }, [content]);

  const Icon = copied ? CheckIcon : CopyIcon;

  return (
    <button
      aria-label={copied ? `Copied ${label}` : `Copy ${label}`}
      className={cn(
        "relative inline-flex size-7 shrink-0 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none [&_svg]:size-3.5",
        className
      )}
      onClick={handleCopy}
      type="button"
    >
      {/* Expands the touch target to 44px on coarse pointers without changing layout. */}
      <span
        aria-hidden="true"
        className="-translate-1/2 absolute top-1/2 left-1/2 size-[max(100%,2.75rem)] pointer-fine:hidden"
      />
      <AnimatePresence mode="popLayout">
        <motion.span
          animate={{ opacity: 1, scale: 1 }}
          exit={{ opacity: 0, scale: 0.5 }}
          initial={{ opacity: 0, scale: 0.5 }}
          key={copied ? "check" : "copy"}
          transition={{ duration: 0.2 }}
        >
          <Icon />
        </motion.span>
      </AnimatePresence>
      <span aria-live="polite" className="sr-only">
        {copied ? "Copied to clipboard" : ""}
      </span>
    </button>
  );
};
