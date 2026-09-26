import React from "react";
import { Sparkles } from "lucide-react";

export default function InsightCard({ insight }) {
  if (!insight) return null;
  return (
    <div className="rounded-2xl bg-gradient-to-br from-accent/25 to-vida-blush/40 border border-accent/40 p-6 animate-fade-in">
      <div className="flex items-center gap-2 mb-3">
        <Sparkles className="w-4 h-4 text-primary" />
        <span className="text-xs uppercase tracking-widest text-primary/70 font-medium">Today's insight</span>
      </div>
      <p className="font-display text-lg sm:text-xl text-primary leading-relaxed text-balance">
        {insight}
      </p>
    </div>
  );
}