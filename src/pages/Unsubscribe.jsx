import React, { useState } from "react";
import { base44 } from "@/api/base44Client";
import { Loader2, Check } from "lucide-react";

const REASONS = [
  { value: "too_many", label: "Too many emails" },
  { value: "not_relevant", label: "Content isn't relevant to me" },
  { value: "mistake", label: "I signed up by mistake" },
  { value: "other_way", label: "I prefer to get updates another way" },
  { value: "other", label: "Other" },
];

export default function Unsubscribe() {
  const urlParams = new URLSearchParams(window.location.search);
  const email = urlParams.get("email") || "";
  const token = urlParams.get("token") || "";
  const [reason, setReason] = useState("");
  const [feedback, setFeedback] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!reason) {
      setError("Please let us know why you're leaving — it helps us improve.");
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await base44.functions.invoke("unsubscribe", { email, token, reason, feedback });
      setDone(true);
    } catch (err) {
      setError("This unsubscribe link is invalid or has expired. Please use the unsubscribe link from your most recent Vida Lab email.");
    }
    setSubmitting(false);
  };

  if (done) {
    return (
      <main className="min-h-[70vh] flex items-center justify-center px-5 py-16">
        <div className="max-w-lg text-center">
          <div className="w-16 h-16 rounded-full bg-accent/20 flex items-center justify-center mx-auto mb-6">
            <Check className="w-7 h-7 text-primary" strokeWidth={1.5} />
          </div>
          <h1 className="font-heading text-3xl text-primary mb-3">You're unsubscribed</h1>
          <p className="text-muted-foreground leading-relaxed">
            We've removed {email ? <strong className="text-primary">{email}</strong> : "your email"} from our mailing list. Thank you for the feedback — it helps us make Vida Lab better.
          </p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-[70vh] flex items-center justify-center px-5 py-16">
      <div className="max-w-lg w-full">
        <div className="text-center mb-8">
          <h1 className="font-heading text-3xl text-primary mb-3">Before you go</h1>
          <p className="text-muted-foreground leading-relaxed">
            We're sorry to see you go. Your feedback helps us improve — please let us know why you're unsubscribing before you leave.
          </p>
        </div>
        <form onSubmit={handleSubmit} className="rounded-3xl bg-card border border-border p-6 sm:p-8 space-y-5">
          <div>
            <label className="block text-sm font-medium text-primary mb-3">Why are you unsubscribing?</label>
            <div className="space-y-2.5">
              {REASONS.map((r) => (
                <label key={r.value} className="flex items-center gap-3 cursor-pointer">
                  <input
                    type="radio"
                    name="reason"
                    value={r.value}
                    checked={reason === r.value}
                    onChange={(e) => setReason(e.target.value)}
                    className="w-4 h-4 accent-primary"
                  />
                  <span className="text-sm text-foreground">{r.label}</span>
                </label>
              ))}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-primary mb-2">
              Anything else? <span className="text-muted-foreground font-normal">(optional)</span>
            </label>
            <textarea
              value={feedback}
              onChange={(e) => setFeedback(e.target.value)}
              rows={3}
              placeholder="We'd love to hear your thoughts…"
              className="w-full px-4 py-2.5 rounded-xl border border-input bg-card text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent resize-none"
            />
          </div>
          {error && <p className="text-sm text-destructive">{error}</p>}
          <button
            type="submit"
            disabled={submitting}
            className="w-full inline-flex items-center justify-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-60"
          >
            {submitting ? <><Loader2 className="w-4 h-4 animate-spin" /> Unsubscribing…</> : "Unsubscribe me"}
          </button>
        </form>
      </div>
    </main>
  );
}