import React from "react";
import { Heart, MessageCircle, TrendingUp } from "lucide-react";

export default function EngagementCard({ engagement }) {
  if (!engagement) return null;
  const { summary, top_posts, trends } = engagement;

  return (
    <div className="rounded-3xl bg-card border border-border p-6 sm:p-8">
      <h2 className="font-heading text-xl text-primary mb-1">Engagement Trends</h2>
      <p className="text-sm text-muted-foreground mb-6">What content resonates with your audience</p>

      {top_posts?.length > 0 && (
        <div className="space-y-3 mb-6">
          {top_posts.map((p, i) => (
            <a
              key={i}
              href={p.permalink}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-start gap-4 p-4 rounded-xl bg-background/50 border border-border hover:border-primary/30 transition-colors"
            >
              <div className="flex-1 min-w-0">
                <p className="text-sm text-foreground line-clamp-2">{p.caption}</p>
                <p className="text-xs text-muted-foreground mt-1">{p.why}</p>
              </div>
              <div className="flex flex-col items-end gap-1 shrink-0 text-xs">
                <span className="flex items-center gap-1 text-muted-foreground">
                  <Heart className="w-3 h-3" /> {p.likes}
                </span>
                <span className="flex items-center gap-1 text-muted-foreground">
                  <MessageCircle className="w-3 h-3" /> {p.comments}
                </span>
              </div>
            </a>
          ))}
        </div>
      )}

      <div className="rounded-xl bg-accent/15 border border-accent/30 p-4 mb-4">
        <p className="text-sm text-foreground leading-relaxed flex items-start gap-2">
          <TrendingUp className="w-4 h-4 text-primary mt-0.5 shrink-0" /> {trends}
        </p>
      </div>
      <p className="text-sm text-muted-foreground leading-relaxed">{summary}</p>
    </div>
  );
}