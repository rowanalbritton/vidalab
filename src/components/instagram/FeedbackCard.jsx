import React from "react";
import { MessageSquare, HelpCircle, Lightbulb } from "lucide-react";

export default function FeedbackCard({ feedback }) {
  if (!feedback) return null;
  const { summary, common_questions, actionable } = feedback;

  return (
    <div className="rounded-3xl bg-card border border-border p-6 sm:p-8">
      <h2 className="font-heading text-xl text-primary mb-1">Community Feedback</h2>
      <p className="text-sm text-muted-foreground mb-6">What people are saying and asking</p>

      <p className="text-sm text-foreground leading-relaxed mb-6 flex items-start gap-2">
        <MessageSquare className="w-4 h-4 text-primary mt-0.5 shrink-0" /> {summary}
      </p>

      {common_questions?.length > 0 && (
        <div className="mb-5">
          <h3 className="text-xs uppercase tracking-widest text-muted-foreground mb-2 flex items-center gap-1.5">
            <HelpCircle className="w-3.5 h-3.5" /> Common Questions
          </h3>
          <ul className="space-y-1.5">
            {common_questions.map((q, i) => (
              <li key={i} className="text-sm text-foreground flex items-start gap-2">
                <span className="text-accent-foreground/40 mt-1">·</span> {q}
              </li>
            ))}
          </ul>
        </div>
      )}

      {actionable?.length > 0 && (
        <div>
          <h3 className="text-xs uppercase tracking-widest text-muted-foreground mb-2 flex items-center gap-1.5">
            <Lightbulb className="w-3.5 h-3.5" /> Actionable Feedback
          </h3>
          <ul className="space-y-1.5">
            {actionable.map((a, i) => (
              <li key={i} className="text-sm text-foreground flex items-start gap-2">
                <span className="text-accent-foreground/40 mt-1">·</span> {a}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}