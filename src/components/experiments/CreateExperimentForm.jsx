import React, { useState } from "react";
import { base44 } from "@/api/base44Client";
import { FlaskConical, Loader2, Sparkles } from "lucide-react";

const METRIC_OPTIONS = [
  { value: "energy", label: "Energy" },
  { value: "sleep_hours", label: "Sleep hours" },
  { value: "sleep_quality", label: "Sleep quality" },
  { value: "mood", label: "Mood" },
  { value: "pain_level", label: "Pain level" },
  { value: "symptoms", label: "Symptoms" },
];

const PRESETS = [
  { title: "Magnesium for sleep", intervention: "Magnesium glycinate 200mg before bed", hypothesis: "This will improve my sleep quality and morning energy", duration_days: 21 },
  { title: "Cutting added sugar", intervention: "No added sugar in my diet", hypothesis: "This will reduce my afternoon energy crashes and brain fog", duration_days: 14 },
  { title: "Morning sunlight", intervention: "10 minutes of morning sunlight within 30 min of waking", hypothesis: "This will improve my energy and mood throughout the day", duration_days: 14 },
  { title: "Iron supplement", intervention: "Iron supplement with vitamin C at breakfast", hypothesis: "This will reduce my fatigue and improve my energy levels", duration_days: 30 },
];

export default function CreateExperimentForm({ onCreated }) {
  const [form, setForm] = useState({
    title: "",
    intervention: "",
    hypothesis: "",
    duration_days: 21,
    metrics_to_watch: ["energy", "sleep_quality", "mood"],
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const toggleMetric = (value) => {
    setForm((f) => ({
      ...f,
      metrics_to_watch: f.metrics_to_watch.includes(value)
        ? f.metrics_to_watch.filter((m) => m !== value)
        : [...f.metrics_to_watch, value],
    }));
  };

  const applyPreset = (preset) => {
    setForm((f) => ({ ...f, ...preset, metrics_to_watch: f.metrics_to_watch }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.title || !form.intervention || !form.hypothesis) return;
    setSaving(true);
    setError(null);
    try {
      const today = new Date().toISOString().slice(0, 10);
      const end = new Date();
      end.setDate(end.getDate() + form.duration_days);
      const end_date = end.toISOString().slice(0, 10);

      const created = await base44.entities.Experiment.create({
        ...form,
        start_date: today,
        end_date,
        status: "active",
      });
      onCreated(created);
      setForm({ title: "", intervention: "", hypothesis: "", duration_days: 21, metrics_to_watch: ["energy", "sleep_quality", "mood"] });
    } catch (e) {
      setError("Could not create experiment. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="rounded-2xl bg-card border border-border p-6 sm:p-8">
      <div className="flex items-center gap-2 mb-5">
        <FlaskConical className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
        <h3 className="font-heading text-xl text-primary">New experiment</h3>
      </div>

      {/* Presets */}
      <div className="mb-6">
        <p className="text-xs uppercase tracking-widest text-muted-foreground mb-2">Quick start</p>
        <div className="flex flex-wrap gap-2">
          {PRESETS.map((p, i) => (
            <button
              key={i}
              type="button"
              onClick={() => applyPreset(p)}
              className="text-sm rounded-full border border-border px-3 py-1.5 text-muted-foreground hover:border-primary hover:text-primary transition-colors"
            >
              {p.title}
            </button>
          ))}
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-5">
        <div>
          <label className="block text-sm font-medium text-primary mb-1.5">Experiment title</label>
          <input
            type="text"
            value={form.title}
            onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
            placeholder="e.g., Magnesium for sleep"
            className="w-full rounded-xl border border-border bg-background px-4 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-primary mb-1.5">What are you testing?</label>
          <input
            type="text"
            value={form.intervention}
            onChange={(e) => setForm((f) => ({ ...f, intervention: e.target.value }))}
            placeholder="e.g., Magnesium glycinate 200mg before bed"
            className="w-full rounded-xl border border-border bg-background px-4 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-primary mb-1.5">Your hypothesis</label>
          <textarea
            value={form.hypothesis}
            onChange={(e) => setForm((f) => ({ ...f, hypothesis: e.target.value }))}
            placeholder="e.g., I think this will improve my sleep quality and morning energy"
            rows={2}
            className="w-full rounded-xl border border-border bg-background px-4 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary resize-none"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-primary mb-1.5">Duration: {form.duration_days} days</label>
          <input
            type="range"
            min={7}
            max={90}
            step={1}
            value={form.duration_days}
            onChange={(e) => setForm((f) => ({ ...f, duration_days: parseInt(e.target.value) }))}
            className="w-full accent-vida-moss"
          />
          <div className="flex justify-between text-xs text-muted-foreground mt-1">
            <span>7 days</span>
            <span>90 days</span>
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-primary mb-2">What to track</label>
          <div className="flex flex-wrap gap-2">
            {METRIC_OPTIONS.map((m) => (
              <button
                key={m.value}
                type="button"
                onClick={() => toggleMetric(m.value)}
                className={`text-sm rounded-full px-3 py-1.5 border transition-colors ${
                  form.metrics_to_watch.includes(m.value)
                    ? "bg-primary text-primary-foreground border-primary"
                    : "border-border text-muted-foreground hover:border-primary"
                }`}
              >
                {m.label}
              </button>
            ))}
          </div>
        </div>

        {error && <p className="text-sm text-destructive">{error}</p>}

        <button
          type="submit"
          disabled={saving || !form.title || !form.intervention || !form.hypothesis}
          className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {saving ? <Loader2 className="w-4 h-4 animate-spin" /> : <Sparkles className="w-4 h-4" />}
          {saving ? "Creating…" : "Start experiment"}
        </button>
      </form>
    </div>
  );
}