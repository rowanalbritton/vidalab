import React from "react";
import { Smile, Meh, Frown } from "lucide-react";

export default function SentimentCard({ sentiment }) {
  if (!sentiment) return null;
  const { summary, positive_pct, neutral_pct, negative_pct, themes } = sentiment;

  const bars = [
    { label: "Positive", pct: positive_pct, color: "bg-vida-moss", icon: Smile },
    { label: "Neutral", pct: neutral_pct, color: "bg-vida-sage", icon: Meh },
    { label: "Negative", pct: negative_pct, color: "bg-vida-clay", icon: Frown },
  ];

  return (
    <div className="rounded-3xl bg-card border border-border p-6 sm:p-8">
      <h2 className="font-heading text-xl text-primary mb-1">Comment Sentiment</h2>
      <p className="text-sm text-muted-foreground mb-6">How people are reacting to your posts</p>
      <div className="space-y-4 mb-6">
        {bars.map((b) => (
          <div key={b.label}>
            <div className="flex justify-between text-sm mb-1.5">
              <span className="text-foreground flex items-center gap-2">
                <b.icon className="w-4 h-4" /> {b.label}
              </span>
              <span className="text-muted-foreground">{b.pct}%</span>
            </div>
            <div className="h-3 rounded-full bg-muted overflow-hidden">
              <div className={`h-full ${b.color} rounded-full transition-all duration-500`} style={{ width: `${b.pct}%` }} />
            </div>
          </div>
        ))}
      </div>
      {themes?.length > 0 && (
        <div className="flex flex-wrap gap-2 mb-4">
          {themes.map((t, i) => (
            <span key={i} className="text-xs px-3 py-1.5 rounded-full bg-accent/15 border border-accent/30 text-primary">{t}</span>
          ))}
        </div>
      )}
      <p className="text-sm text-muted-foreground leading-relaxed">{summary}</p>
    </div>
  );
}