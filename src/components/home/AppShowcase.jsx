import React from "react";
import { motion } from "framer-motion";

const SCREENSHOTS = [
  {
    src: "https://media.base44.com/images/public/6aacae7dbd22557932ef6597/eeeae2050_IMG_00982.PNG",
    alt: "VIDA LAB Today dashboard",
    label: "Today",
  },
  {
    src: "https://media.base44.com/images/public/6aacae7dbd22557932ef6597/f2b1d8c71_IMG_00992.PNG",
    alt: "VIDA LAB health metrics and insights",
    label: "Insights",
  },
  {
    src: "https://media.base44.com/images/public/6aacae7dbd22557932ef6597/41e3604f0_IMG_01002.PNG",
    alt: "VIDA LAB Pattern Map",
    label: "Pattern Map",
  },
  {
    src: "https://media.base44.com/images/public/6aacae7dbd22557932ef6597/16d67e9ad_IMG_01012.PNG",
    alt: "VIDA LAB Pattern Map threads",
    label: "Threads",
  },
];

export default function AppShowcase() {
  return (
    <div className="app-showcase">
      {SCREENSHOTS.map((shot, i) => (
        <motion.div
          key={shot.label}
          className={`app-screen app-screen-${i + 1}`}
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: "-60px" }}
          transition={{
            duration: 0.9,
            ease: [0.25, 0.1, 0.25, 1],
            delay: i * 0.12,
          }}
        >
          <img src={shot.src} alt={shot.alt} className="app-screen-img" />
          <div className="app-screen-overlay" aria-hidden="true" />
          <span className="app-screen-label">{shot.label}</span>
        </motion.div>
      ))}
    </div>
  );
}