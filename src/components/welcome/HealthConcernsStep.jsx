import React, { useState } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import { Check, Loader2 } from "lucide-react";

const HEALTH_CATEGORIES = [
  { value: "autoimmune", label: "Autoimmune" },
  { value: "neurological", label: "Neurological" },
  { value: "cardiovascular", label: "Cardiovascular" },
  { value: "endocrine", label: "Endocrine / Hormonal" },
  { value: "musculoskeletal", label: "Musculoskeletal" },
  { value: "gastrointestinal", label: "Gastrointestinal" },
  { value: "respiratory", label: "Respiratory" },
  { value: "mental_health", label: "Mental health" },
  { value: "chronic_pain", label: "Chronic pain" },
  { value: "dysautonomia", label: "Dysautonomia" },
  { value: "gynecological", label: "Gynecological" },
  { value: "other", label: "Other / just curious" },
];

export default function HealthConcernsStep({ onComplete }) {
  const { checkUserAuth } = useAuth();
  const [selected, setSelected] = useState([]);
  const [condition, setCondition] = useState("");
  const [saving, setSaving] = useState(false);

  const toggle = (value) => {
    setSelected((prev) =>
      prev.includes(value) ? prev.filter((v) => v !== value) : [...prev, value]
    );
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      await base44.auth.updateMe({
        health_concerns: selected,
        specific_condition: condition || undefined,
      });
      await checkUserAuth();
    } catch (e) {
      console.error("Failed to save health concerns", e);
    }
    setSaving(false);
    onComplete();
  };

  return (
    <div className="max-w-lg mx-auto">
      <div className="text-center mb-8">
        <div className="eyebrow mb-2">Step 2 · What you're tracking</div>
        <h2 className="font-heading text-3xl text-primary">What health concerns are you tracking?</h2>
        <p className="text-muted-foreground mt-2">
          Select any that apply. This helps us surface relevant patterns, explainers, and resources. You can change these anytime.
        </p>
      </div>

      <div className="rounded-3xl bg-card border border-border p-6 sm:p-8">
        <div className="flex flex-wrap gap-2 mb-6">
          {HEALTH_CATEGORIES.map((c) => {
            const active = selected.includes(c.value);
            return (
              <button
                key={c.value}
                type="button"
                onClick={() => toggle(c.value)}
                className={`px-4 py-2 rounded-full border text-sm transition-all flex items-center gap-1.5 ${
                  active
                    ? "bg-accent/30 border-accent text-primary"
                    : "bg-card border-border text-muted-foreground hover:border-primary/40"
                }`}
              >
                {active && <Check className="w-3.5 h-3.5" />}
                {c.label}
              </button>
            );
          })}
        </div>

        <div>
          <label className="block text-sm font-medium text-primary mb-2">
            Do you have a specific condition? <span className="text-muted-foreground font-normal">(optional)</span>
          </label>
          <input
            type="text"
            value={condition}
            onChange={(e) => setCondition(e.target.value)}
            placeholder="e.g. Hashimoto's, POTS, endometriosis, migraine…"
            className="w-full px-4 py-2.5 rounded-xl border border-input bg-card text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent"
          />
        </div>
      </div>

      <button
        onClick={handleSave}
        disabled={saving}
        className="w-full mt-6 inline-flex items-center justify-center gap-2 rounded-full px-8 py-3.5 bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-60"
      >
        {saving ? <><Loader2 className="w-4 h-4 animate-spin" /> Saving…</> : "Continue →"}
      </button>
    </div>
  );
}