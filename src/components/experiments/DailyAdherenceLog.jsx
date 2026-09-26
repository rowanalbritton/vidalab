import React, { useState, useEffect } from "react";
import { base44 } from "@/api/base44Client";
import { Check, X, Loader2 } from "lucide-react";

export default function DailyAdherenceLog({ experiment, logs, onLogged }) {
  const today = new Date().toISOString().slice(0, 10);
  const existing = logs.find((l) => (l.log_date || "").slice(0, 10) === today);

  const [adhered, setAdhered] = useState(existing?.adhered ?? null);
  const [notes, setNotes] = useState(existing?.notes || "");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    setAdhered(existing?.adhered ?? null);
    setNotes(existing?.notes || "");
  }, [existing]);

  const handleSave = async () => {
    if (adhered === null) return;
    setSaving(true);
    try {
      if (existing) {
        await base44.entities.ExperimentLog.update(existing.id, { adhered, notes });
      } else {
        await base44.entities.ExperimentLog.create({
          experiment_id: experiment.id,
          log_date: today,
          adhered,
          notes,
        });
      }
      onLogged?.();
    } catch (e) {
      console.error(e);
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="rounded-2xl bg-card border border-border p-6">
      <p className="text-sm font-medium text-primary mb-1">Did you do your intervention today?</p>
      <p className="text-xs text-muted-foreground mb-4">{experiment.intervention}</p>

      <div className="flex gap-3 mb-4">
        <button
          onClick={() => setAdhered(true)}
          className={`flex-1 inline-flex items-center justify-center gap-2 py-3 rounded-xl border text-sm font-medium transition-colors ${
            adhered === true
              ? "bg-vida-moss text-primary-foreground border-vida-moss"
              : "border-border text-muted-foreground hover:border-vida-moss"
          }`}
        >
          <Check className="w-4 h-4" /> Yes, I did it
        </button>
        <button
          onClick={() => setAdhered(false)}
          className={`flex-1 inline-flex items-center justify-center gap-2 py-3 rounded-xl border text-sm font-medium transition-colors ${
            adhered === false
              ? "bg-vida-taupe text-primary-foreground border-vida-taupe"
              : "border-border text-muted-foreground hover:border-vida-taupe"
          }`}
        >
          <X className="w-4 h-4" /> Not today
        </button>
      </div>

      <textarea
        value={notes}
        onChange={(e) => setNotes(e.target.value)}
        placeholder="Notes (optional) — how did you feel today?"
        rows={2}
        className="w-full rounded-xl border border-border bg-background px-4 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary resize-none mb-4"
      />

      <button
        onClick={handleSave}
        disabled={adhered === null || saving}
        className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
        {saving ? "Saving…" : existing ? "Update log" : "Log today"}
      </button>
    </div>
  );
}