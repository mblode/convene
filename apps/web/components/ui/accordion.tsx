"use client";

import { Accordion as AccordionPrimitive } from "@base-ui/react/accordion";
import { createContext, useCallback, useContext, useState } from "react";
import type { ComponentProps } from "react";

import { cn } from "@/lib/utils";

type AccordionValue = string | string[];

/** Open state lives in React and flows down, rather than being mirrored back
 * out of the DOM. The panel needs the value during render, and reading it from
 * data attributes after the fact is a frame late and fragile across versions. */
const OpenValuesContext = createContext<string[]>([]);
const ItemValueContext = createContext<string | null>(null);

const useIsOpen = () => {
  const openValues = useContext(OpenValuesContext);
  const itemValue = useContext(ItemValueContext);
  return itemValue !== null && openValues.includes(itemValue);
};

const toArray = (value: AccordionValue | undefined): string[] => {
  if (value === undefined) {
    return [];
  }
  if (Array.isArray(value)) {
    return value;
  }
  return value === "" ? [] : [value];
};

type AccordionProps = Omit<
  ComponentProps<typeof AccordionPrimitive.Root>,
  "defaultValue" | "multiple" | "onValueChange" | "value"
> & {
  type?: "single" | "multiple";
  collapsible?: boolean;
  value?: AccordionValue;
  defaultValue?: AccordionValue;
  onValueChange?: (value: AccordionValue) => void;
};

const Accordion = ({
  type = "single",
  collapsible = false,
  value,
  defaultValue,
  onValueChange,
  children,
  ...props
}: AccordionProps) => {
  const multiple = type === "multiple";
  const [uncontrolled, setUncontrolled] = useState<string[]>(() =>
    toArray(defaultValue)
  );
  const isControlled = value !== undefined;
  const openValues = isControlled ? toArray(value) : uncontrolled;

  const handleValueChange = useCallback(
    (nextValue: (unknown | null)[]) => {
      const next = nextValue.filter(
        (item): item is string => typeof item === "string"
      );
      // A single-select accordion that isn't collapsible keeps the last item
      // open rather than closing to nothing.
      const resolved =
        !(multiple || collapsible) && next.length === 0 ? openValues : next;

      if (!isControlled) {
        setUncontrolled(resolved);
      }
      onValueChange?.(multiple ? resolved : (resolved[0] ?? ""));
    },
    [collapsible, isControlled, multiple, onValueChange, openValues]
  );

  return (
    <OpenValuesContext.Provider value={openValues}>
      <AccordionPrimitive.Root
        data-slot="accordion"
        multiple={multiple}
        onValueChange={handleValueChange}
        value={openValues}
        {...props}
      >
        {children}
      </AccordionPrimitive.Root>
    </OpenValuesContext.Provider>
  );
};

const AccordionItem = ({
  className,
  children,
  value,
  ...props
}: ComponentProps<typeof AccordionPrimitive.Item> & { value: string }) => (
  <ItemValueContext.Provider value={value}>
    <AccordionPrimitive.Item
      className={cn("border-b last:border-b-0", className)}
      data-slot="accordion-item"
      value={value}
      {...props}
    >
      {children}
    </AccordionPrimitive.Item>
  </ItemValueContext.Provider>
);

const AccordionTrigger = ({
  className,
  children,
  ...props
}: ComponentProps<typeof AccordionPrimitive.Trigger>) => {
  const isOpen = useIsOpen();

  return (
    <AccordionPrimitive.Header className="flex">
      <AccordionPrimitive.Trigger
        className={cn(
          "flex flex-1 items-start justify-between gap-6 rounded-md py-5 text-left font-medium text-base outline-none transition-colors hover:text-muted-foreground focus-visible:ring-3 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50",
          className
        )}
        data-slot="accordion-trigger"
        {...props}
      >
        {children}
        {/* Plus morphing to minus. Two bars and a CSS transform — no animation
            library in the path, so it degrades to an instant swap at worst. */}
        <span
          aria-hidden="true"
          className="relative mt-1.5 flex size-3 shrink-0 items-center justify-center"
        >
          <span className="absolute h-[1.5px] w-3 rounded-full bg-foreground" />
          <span
            className={cn(
              "absolute h-3 w-[1.5px] rounded-full bg-foreground transition-transform duration-300 ease-[cubic-bezier(0.645,0.045,0.355,1)]",
              isOpen && "scale-y-0"
            )}
          />
        </span>
      </AccordionPrimitive.Trigger>
    </AccordionPrimitive.Header>
  );
};

/** Height animates through `grid-template-rows: 0fr → 1fr`, which needs no
 * measurement and no JS. If transitions are disabled the panel simply snaps
 * open — it can never be left clipped with its content unreachable. */
const AccordionContent = ({
  className,
  children,
  ...props
}: ComponentProps<typeof AccordionPrimitive.Panel>) => {
  const isOpen = useIsOpen();

  return (
    <AccordionPrimitive.Panel keepMounted {...props} hidden={false}>
      <div
        className={cn(
          "grid transition-[grid-template-rows,opacity] duration-300 ease-[cubic-bezier(0.25,1,0.5,1)] motion-reduce:transition-none",
          isOpen ? "grid-rows-[1fr] opacity-100" : "grid-rows-[0fr] opacity-0"
        )}
        data-slot="accordion-content"
      >
        <div className="overflow-hidden">
          <div
            className={cn(
              "max-w-[68ch] pt-0 pb-6 text-[0.9375rem] text-muted-foreground leading-relaxed",
              className
            )}
          >
            {children}
          </div>
        </div>
      </div>
    </AccordionPrimitive.Panel>
  );
};

export { Accordion, AccordionContent, AccordionItem, AccordionTrigger };
