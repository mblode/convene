import { Button as ButtonPrimitive } from "@base-ui/react/button";
import { cva } from "class-variance-authority";
import type { VariantProps } from "class-variance-authority";
import { isValidElement } from "react";

import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "group/button inline-flex shrink-0 items-center justify-center rounded-lg border border-transparent bg-clip-padding font-medium text-sm whitespace-nowrap transition-[color,background-color,border-color,box-shadow,opacity,transform] duration-150 ease-out outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 active:not-aria-[haspopup]:translate-y-px disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    defaultVariants: {
      size: "default",
      variant: "default",
    },
    variants: {
      size: {
        default: "h-9 gap-2 px-3.5",
        icon: "size-9",
        lg: "h-11 gap-2 px-5 text-[0.9375rem]",
        sm: "h-8 gap-1.5 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem]",
      },
      variant: {
        default:
          "border-primary-foreground/10 bg-primary text-primary-foreground [a]:hover:bg-primary/85",
        ghost: "hover:bg-muted hover:text-foreground aria-expanded:bg-muted",
        link: "text-link underline-offset-4 hover:underline",
        outline:
          "border-border bg-background hover:bg-muted hover:text-foreground",
        secondary:
          "border-[var(--color-theme-border-01)] bg-secondary text-secondary-foreground hover:bg-secondary/70",
      },
    },
  }
);

const Button = ({
  className,
  variant = "default",
  size = "default",
  nativeButton,
  render,
  ...props
}: ButtonPrimitive.Props & VariantProps<typeof buttonVariants>) => {
  // When rendered as a non-button element (e.g. an <a>), tell Base UI not to
  // expect native button semantics. Otherwise it warns about a missing <button>.
  const rendersNativeButton = !(
    isValidElement(render) && render.type !== "button"
  );

  return (
    <ButtonPrimitive
      className={cn(buttonVariants({ className, size, variant }))}
      data-slot="button"
      nativeButton={nativeButton ?? rendersNativeButton}
      render={render}
      {...props}
    />
  );
};

export { Button, buttonVariants };
