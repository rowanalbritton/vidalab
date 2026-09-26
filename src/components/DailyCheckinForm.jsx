import React, { useState } from "react";
import { Button } from "@/components/ui/button";
import { Loader2, Check } from "lucide-react";
import { generateInsight } from "@/lib/insights";
import { useAuth } from "@/lib/AuthContext";

const MOODS = [
  { value: "calm", label: "Calm" },
  { value: "happy", label: "Bright" },
  { value: "neutral", label: "Steady" },
  { value: "motivated", label: "Motivated" },
  { value: "anxious", label: "Anxious" },
  { value: "irritable", label: "Irritable" },
  { value: "sad", label: "Low" },
];

const SYMPTOMS = [
  { value: "headache", label: "Headache" },
  { value: "cramps", label: "Cramps" },
  { value: "bloating", label: "Bloating" },
  { value: "fatigue", label: "Fatigue" },
  { value: "breast_tenderness", label: "Tenderness" },
  { value: "acne", label: "Skin changes" },
  { value: "backache", label: "Back ache" },
  { value: "nausea", label: "Nausea" },
  { value: "brain_fog", label: "Brain fog" },
  { value: "cravings", label: "Cravings" },
];

const PRACTICES = [
  { value: "meditation", label: "Meditation" },
  { value: "gentle_exercise", label: "Gentle exercise" },
  { value: "anti_inflammatory_meal", label: "Anti-inflammatory meal" },
  { value: "supplement", label: "Supplement" },
  { value: "breathing_exercise", label: "Breathing exercise" },
  { value: "nature_time", label: "Nature time" },
  { value: "sleep_hygiene", label: "Sleep hygiene" },
  { value: "hydration", label: "Hydration" },
  { value: "gratitude", label: "Gratitude" },
  { value: "stretching", label: "Stretching" },
];

const CYCLE_PHASES = [
  { value: "not_tracking", label: "Not tracking" },
  { value: "menstrual", label: "Menstrual" },
  { value: "follicular", label: "Follicular" },
  { value: "ovulation", label: "Ovulation" },
  { value: "luteal", label: "Luteal" },
];

function ScalePicker({ value, onChange, count, labels }) {
  return (
    <div className="flex gap-2">
      {Array.from({ length: count }, (_, i) => i + 1).map((n) => (
        <button
          key={n}
          type="button"
          onClick={() => onChange(n)}
          className={`flex-1 py-3 rounded-xl border text-sm font-medium transition-all ${
            value === n
              ? "bg-primary text-primary-foreground border-primary"
              : "bg-card border-border text-muted-foreground hover:border-primary/40"
          }`}
        >
          <div className="text-lg font-heading">{n}</div>
          <div className="text-[10px] mt-0.5">{labels?.[n - 1]}</div>
        </button>
      ))}
    </div>
  );
}

export default function DailyCheckinForm({ onSaved, existing }) {
  const { user } = useAuth();
  const [form, setForm] = useState({
    checkin_date: new Date().toISOString().split("T")[0],
    energy: existing?.energy ?? 3,
    sleep_hours: existing?.sleep_hours ?? "",
    sleep_quality: existing?.sleep_quality ?? 3,
    mood: existing?.mood ?? "neutral",
    pain_level: existing?.pain_level ?? 0,
    cycle_phase: existing?.cycle_phase ?? "not_tracking",
    symptoms: existing?.symptoms ?? [],
    practices: existing?.practices ?? [],
    notes: existing?.notes ?? "",
  });
  const [saving, setSaving] = useState(false);

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const toggleSymptom = (s) => {
    setForm((f) => {
      const has = f.symptoms.includes(s);
      const next = has ? f.symptoms.filter((x) => x !== s) : [...f.symptoms, s];
      return { ...f, symptoms: next };
    });
  };

  const togglePractice = (p) => {
    setForm((f) => {
      const has = f.practices.includes(p);
      const next = has ? f.practices.filter((x) => x !== p) : [...f.practices, p];
      return { ...f, practices: next };
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setSaving(true);
    const insight = generateInsight(form);
    const payload = {
      ...form,
      sleep_hours: form.sleep_hours === "" ? null : Number(form.sleep_hours),
      symptoms: form.symptoms.length ? form.symptoms : ["none"],
      practices: form.practices,
      insight,
    };
    await onSaved(payload);
    setSaving(false);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-7">
      <div>
        <label className="block text-sm font-medium text-primary mb-2">Date</label>
        <input
          type="date"
          value={form.checkin_date}
          onChange={(e) => set("checkin_date", e.target.value)}
          className="w-full sm:w-48 px-4 py-2.5 rounded-xl border border-input bg-card text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent"
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-primary mb-2">Energy <span className="text-muted-foreground font-normal">(1 exhausted → 5 vibrant)</span></label>
        <ScalePicker value={form.energy} onChange={(v) => set("energy", v)} count={5} labels={["Exhausted", "Low", "Steady", "Good", "Vibrant"]} />
      </div>

      <div className="grid sm:grid-cols-2 gap-5">
        <div>
          <label className="block text-sm font-medium text-primary mb-2">Hours slept</label>
          <input
            type="number" min="0" max="14" step="0.5"
            value={form.sleep_hours}
            onChange={(e) => set("sleep_hours", e.target.value)}
            placeholder="e.g. 7.5"
            className="w-full px-4 py-2.5 rounded-xl border border-input bg-card text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-primary mb-2">Sleep quality <span className="text-muted-foreground font-normal">(1–5)</span></label>
          <ScalePicker value={form.sleep_quality} onChange={(v) => set("sleep_quality", v)} count={5} />
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-primary mb-2">Mood</label>
        <div className="flex flex-wrap gap-2">
          {MOODS.map((m) => (
            <button
              key={m.value} type="button"
              onClick={() => set("mood", m.value)}
              className={`px-4 py-2 rounded-full border text-sm transition-all ${
                form.mood === m.value
                  ? "bg-primary text-primary-foreground border-primary"
                  : "bg-card border-border text-muted-foreground hover:border-primary/40"
              }`}
            >
              {m.label}
            </button>
          ))}
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-primary mb-2">Pain level <span className="text-muted-foreground font-normal">(0 none → 3 severe)</span></label>
        <ScalePicker value={form.pain_level} onChange={(v) => set("pain_level", v)} count={4} labels={["None", "Mild", "Moderate", "Severe"]} />
      </div>

      {user?.gender === "female" && (
        <div>
          <label className="block text-sm font-medium text-primary mb-2">Cycle phase <span className="text-muted-foreground font-normal">(optional — skip if not applicable)</span></label>
          <div className="flex flex-wrap gap-2">
            {CYCLE_PHASES.map((c) => (
              <button
                key={c.value} type="button"
                onClick={() => set("cycle_phase", c.value)}
                className={`px-4 py-2 rounded-full border text-sm transition-all ${
                  form.cycle_phase === c.value
                    ? "bg-primary text-primary-foreground border-primary"
                    : "bg-card border-border text-muted-foreground hover:border-primary/40"
                }`}
              >
                {c.label}
              </button>
            ))}
          </div>
        </div>
      )}

      <div>
        <label className="block text-sm font-medium text-primary mb-2">Symptoms <span className="text-muted-foreground font-normal">(select any that apply)</span></label>
        <div className="flex flex-wrap gap-2">
          {SYMPTOMS.map((s) => {
            const active = form.symptoms.includes(s.value);
            return (
              <button
                key={s.value} type="button"
                onClick={() => toggleSymptom(s.value)}
                className={`px-4 py-2 rounded-full border text-sm transition-all flex items-center gap-1.5 ${
                  active ? "bg-accent/30 border-accent text-primary" : "bg-card border-border text-muted-foreground hover:border-primary/40"
                }`}
              >
                {active && <Check className="w-3.5 h-3.5" />}
                {s.label}
              </button>
            );
          })}
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-primary mb-2">Today's practices <span className="text-muted-foreground font-normal">(from the Vida Apothecary)</span></label>
        <p className="text-xs text-muted-foreground mb-2">Tag what you did today — we'll show how each habit affects your mood and pain over time.</p>
        <div className="flex flex-wrap gap-2">
          {PRACTICES.map((p) => {
            const active = form.practices.includes(p.value);
            return (
              <button
                key={p.value} type="button"
                onClick={() => togglePractice(p.value)}
                className={`px-4 py-2 rounded-full border text-sm transition-all flex items-center gap-1.5 ${
                  active ? "bg-accent/30 border-accent text-primary" : "bg-card border-border text-muted-foreground hover:border-primary/40"
                }`}
              >
                {active && <Check className="w-3.5 h-3.5" />}
                {p.label}
              </button>
            );
          })}
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-primary mb-2">Notes <span className="text-muted-foreground font-normal">(optional)</span></label>
        <textarea
          value={form.notes}
          onChange={(e) => set("notes", e.target.value)}
          rows={3}
          placeholder="Anything else worth remembering today…"
          className="w-full px-4 py-2.5 rounded-xl border border-input bg-card text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent resize-none"
        />
      </div>

      <Button type="submit" disabled={saving} className="w-full sm:w-auto rounded-full px-8 py-3 text-sm font-medium">
        {saving ? <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> Saving…</> : "Save today's signals"}
      </Button>
    </form>
  );
}