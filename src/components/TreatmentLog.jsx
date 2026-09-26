import React, { useState, useEffect } from "react";
import { base44 } from "@/api/base44Client";
import { Plus, Trash2, Loader2, X } from "lucide-react";
import Loader from "@/components/Loader";

const TYPES = [
  { value: "medication", label: "Medication" },
  { value: "supplement", label: "Supplement" },
  { value: "therapy", label: "Therapy" },
  { value: "lifestyle", label: "Lifestyle" },
  { value: "procedure", label: "Procedure" },
  { value: "other", label: "Other" },
];

const EMPTY = {
  name: "", type: "medication", start_date: "", end_date: "",
  dosage: "", effectiveness: 3, side_effects: "", notes: "", status: "past",
};

export default function TreatmentLog() {
  const [treatments, setTreatments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState(EMPTY);

  const load = () =>
    base44.entities.Treatment.list("-start_date", 200)
      .then(setTreatments).catch(() => {}).finally(() => setLoading(false));

  useEffect(() => { load(); }, []);

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await base44.entities.Treatment.create(form);
      setForm(EMPTY);
      setShowForm(false);
      await load();
    } catch (_) {} finally { setSaving(false); }
  };

  const remove = async (id) => {
    try { await base44.entities.Treatment.delete(id); setTreatments(treatments.filter(t => t.id !== id)); } catch (_) {}
  };

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  if (loading) return <div className="flex justify-center py-8"><Loader /></div>;

  return (
    <div className="mt-12">
      <div className="flex items-center justify-between mb-4">
        <div>
          <span className="text-xs uppercase tracking-widest text-muted-foreground">Treatment History</span>
          <h2 className="font-heading text-2xl text-primary">What you've tried</h2>
          <p className="text-sm text-muted-foreground mt-1">Log medications, supplements, and therapies so you can see what worked — and share it with your doctor.</p>
        </div>
        <button onClick={() => setShowForm(s => !s)} className="inline-flex items-center gap-1.5 px-4 py-2 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors shrink-0">
          {showForm ? <><X className="w-3.5 h-3.5" /> Cancel</> : <><Plus className="w-3.5 h-3.5" /> Add</>}
        </button>
      </div>

      {showForm && (
        <form onSubmit={submit} className="rounded-2xl bg-card border border-border p-6 mb-6 space-y-4">
          <div className="grid sm:grid-cols-2 gap-4">
            <div>
              <label className="text-xs uppercase tracking-widest text-muted-foreground block mb-1.5">Name *</label>
              <input required value={form.name} onChange={e => set("name", e.target.value)} className="w-full rounded-xl border border-border bg-background px-3 py-2 text-sm" placeholder="e.g. Magnesium glycinate" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-muted-foreground block mb-1.5">Type</label>
              <select value={form.type} onChange={e => set("type", e.target.value)} className="w-full rounded-xl border border-border bg-background px-3 py-2 text-sm">
                {TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-muted-foreground block mb-1.5">Start date</label>
              <input type="date" value={form.start_date} onChange={e => set("start_date", e.target.value)} className="w-full rounded-xl border border-border bg-background px-3 py-2 text-sm" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-muted-foreground block mb-1.5">End date</label>
              <input type="date" value={form.end_date} onChange={e => set("end_date", e.target.value)} className="w-full rounded-xl border border-border bg-background px-3 py-2 text-sm" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-muted-foreground block mb-1.5">Dosage / details</label>
              <input value={form.dosage} onChange={e => set("dosage", e.target.value)} className="w-full rounded-xl border border-border bg-background px-3 py-2 text-sm" placeholder="e.g. 200mg before bed" />
            </div>
            <div>
              <label className="text-xs uppercase tracking-widest text-muted-foreground block mb-1.5">Effectiveness: {form.effectiveness}/5</label>
              <input type="range" min="1" max="5" value={form.effectiveness} onChange={e => set("effectiveness", Number(e.target.value))} className="w-full accent-vida-moss mt-2" />
            </div>
          </div>
          <div>
            <label className="text-xs uppercase tracking-widest text-muted-foreground block mb-1.5">Side effects</label>
            <input value={form.side_effects} onChange={e => set("side_effects", e.target.value)} className="w-full rounded-xl border border-border bg-background px-3 py-2 text-sm" placeholder="e.g. Drowsiness, none" />
          </div>
          <div>
            <label className="text-xs uppercase tracking-widest text-muted-foreground block mb-1.5">Notes</label>
            <textarea value={form.notes} onChange={e => set("notes", e.target.value)} rows={2} className="w-full rounded-xl border border-border bg-background px-3 py-2 text-sm" placeholder="What did you notice? Did it help?" />
          </div>
          <div>
            <label className="text-xs uppercase tracking-widest text-muted-foreground block mb-1.5">Status</label>
            <select value={form.status} onChange={e => set("status", e.target.value)} className="w-full rounded-xl border border-border bg-background px-3 py-2 text-sm">
              <option value="current">Currently taking</option>
              <option value="past">Past treatment</option>
              <option value="discontinued">Discontinued</option>
            </select>
          </div>
          <button type="submit" disabled={saving} className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-50">
            {saving && <Loader2 className="w-3.5 h-3.5 animate-spin" />} Save treatment
          </button>
        </form>
      )}

      {treatments.length === 0 ? (
        <div className="text-center py-10 rounded-2xl border border-dashed border-border">
          <p className="text-muted-foreground text-sm">No treatments logged yet. Add what you've tried — medications, supplements, therapies — so you can see what worked.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {treatments.map(t => (
            <div key={t.id} className="rounded-2xl bg-card border border-border p-5">
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1 flex-wrap">
                    <h3 className="font-heading text-base text-primary">{t.name}</h3>
                    <span className="text-xs px-2 py-0.5 rounded-full bg-muted text-muted-foreground">{TYPES.find(x => x.value === t.type)?.label || t.type}</span>
                    {t.status === "current" && <span className="text-xs px-2 py-0.5 rounded-full bg-vida-moss/15 text-vida-moss">Current</span>}
                    {t.status === "discontinued" && <span className="text-xs px-2 py-0.5 rounded-full bg-destructive/10 text-destructive">Discontinued</span>}
                  </div>
                  {t.dosage && <p className="text-sm text-muted-foreground">{t.dosage}</p>}
                  <div className="flex flex-wrap gap-x-4 gap-y-1 mt-2 text-xs text-muted-foreground">
                    {t.start_date && <span>{t.start_date}{t.end_date ? ` → ${t.end_date}` : " → present"}</span>}
                    {t.effectiveness && <span>Effectiveness: {"●".repeat(t.effectiveness)}{"○".repeat(5 - t.effectiveness)}</span>}
                  </div>
                  {t.side_effects && <p className="text-xs text-muted-foreground mt-1.5">Side effects: {t.side_effects}</p>}
                  {t.notes && <p className="text-xs text-muted-foreground mt-1.5 italic">{t.notes}</p>}
                </div>
                <button onClick={() => remove(t.id)} className="text-muted-foreground hover:text-destructive transition-colors shrink-0">
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}