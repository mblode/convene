"use client";
"use no memo";

import { useEffect, useRef, useState } from "react";

/** Drives a looping mock animation as a step counter.
 *
 * Two things every mock on this page needs, and neither is free:
 * - it stops advancing while scrolled out of view, so seven mocks don't all
 *   run timers at once, and
 * - it parks on `reducedStep` and never ticks when the visitor has asked for
 *   reduced motion, so the frame they see is a deliberate one rather than
 *   whichever frame the loop happened to be on.
 *
 * `active` is the same condition, exposed so CSS keyframe loops (the pulsing
 * record dot, the caret) can be switched off under the same rules. A CSS
 * animation keeps burning compositor time off-screen otherwise.
 */
export const useMockClock = ({
  initialStep = 0,
  intervalMs,
  steps,
  reducedStep,
}: {
  /** The frame the server renders, before any tick.
   *
   * Defaults to 0, which is what every mock written before this option existed
   * gets — an empty frame that fills in on hydration. That is fine for a mock
   * whose whole job is to animate, and wrong for one whose job is to *prove*
   * something: a reader with JS disabled would see an empty box where the
   * argument was supposed to be. Pass `reducedStep` and the finished frame is
   * in the HTML, with the loop rewinding it after mount.
   *
   * Added rather than changed for the same reason it is optional: five mocks
   * already depend on starting at 0, and none of their behaviour moves. */
  initialStep?: number;
  intervalMs: number;
  steps: number;
  reducedStep: number;
}) => {
  const ref = useRef<HTMLDivElement | null>(null);
  const [step, setStep] = useState(initialStep);
  const [reduced, setReduced] = useState(false);
  const [inView, setInView] = useState(false);

  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const apply = () => {
      setReduced(query.matches);
      if (query.matches) {
        setStep(reducedStep);
      }
    };
    apply();
    query.addEventListener("change", apply);
    return () => query.removeEventListener("change", apply);
  }, [reducedStep]);

  useEffect(() => {
    const el = ref.current;
    if (!el) {
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => setInView(entry.isIntersecting),
      {
        threshold: 0.15,
      }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (reduced || !inView) {
      return;
    }
    const timer = setInterval(
      () => setStep((current) => (current + 1) % steps),
      intervalMs
    );
    return () => clearInterval(timer);
  }, [inView, intervalMs, reduced, steps]);

  return { active: inView && !reduced, reduced, ref, step };
};
