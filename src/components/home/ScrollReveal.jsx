import React from "react";
import { motion } from "framer-motion";

// Oura-inspired scroll reveal: text gently fades and rises into view
// as the user scrolls, then stays in place (animates once, never reverses).
// Subtle, slow, and elegant — designed for a luxury scrolling feel.
export default function ScrollReveal({
  children,
  delay = 0,
  y = 20,
  duration = 0.9,
  className = "",
  as = "div",
}) {
  const MotionTag = motion[as] || motion.div;
  return (
    <MotionTag
      className={className}
      initial={{ opacity: 0, y }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-50px" }}
      transition={{ duration, ease: [0.25, 0.1, 0.25, 1], delay }}
    >
      {children}
    </MotionTag>
  );
}

// Staggered group: wraps children that each animate in sequence.
// Use <StaggerGroup> around <StaggerItem> elements.
export function StaggerGroup({ children, className = "", stagger = 0.08, delay = 0 }) {
  return (
    <motion.div
      className={className}
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, margin: "-50px" }}
      variants={{
        hidden: {},
        visible: {
          transition: { staggerChildren: stagger, delayChildren: delay },
        },
      }}
    >
      {children}
    </motion.div>
  );
}

export function StaggerItem({ children, className = "", y = 20 }) {
  return (
    <motion.div
      className={className}
      variants={{
        hidden: { opacity: 0, y },
        visible: {
          opacity: 1,
          y: 0,
          transition: { duration: 0.8, ease: [0.25, 0.1, 0.25, 1] },
        },
      }}
    >
      {children}
    </motion.div>
  );
}