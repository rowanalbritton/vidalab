import React, { useState, useEffect, useMemo, useRef } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import MembershipGate from "@/components/MembershipGate";
import AppointmentConcierge from "@/components/AppointmentConcierge";
import TreatmentLog from "@/components/TreatmentLog";
import { buildHealthSnapshot } from "@/lib/healthSnapshot";
import { Printer, Sparkles } from "lucide-react";
import Loader from "@/components/Loader";

export default function DoctorPrep() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";
  const [checkins, setCheckins] = useState([]);
  const [loading, setLoading] = useState(true);
  const printRef = useRef(null);

  useEffect(() => {
    if (!isVidaPlus) { setLoading(false); return; }
    base44.entities.DailyCheckin.list("-checkin_date", 500)
      .then(setCheckins)
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [isVidaPlus]);

  const snapshot = useMemo(() => buildHealthSnapshot(checkins), [checkins]);

  if (!isVidaPlus) return <MembershipGate title="Doctor Prep" />;
  if (loading) return <div className="flex justify-center py-24"><Loader /></div>;

  return (
    <main className="max-w-3xl mx-auto px-5 sm:px-8 py-10">
      <div className="mb-8 print:hidden">
        <span className="text-xs uppercase tracking-widest text-muted-foreground">Appointment Concierge · Vida+</span>
        <h1 className="font-heading text-4xl text-primary mt-1">Appointment Concierge</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">Walk in prepared. Your check-ins become a health snapshot, predicted questions, an advocacy script, and tests to ask about — so you're heard, not dismissed.</p>
        {snapshot && (
          <button
            onClick={() => window.print()}
            className="mt-5 inline-flex items-center gap-2 px-5 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <Printer className="w-4 h-4" /> Print snapshot
          </button>
        )}
      </div>

      {!snapshot ? (
        <div className="text-center py-16 rounded-2xl border border-dashed border-border">
          <p className="text-muted-foreground">Log a few check-ins first — your snapshot builds from your tracked data.</p>
        </div>
      ) : (
        <div ref={printRef} className="rounded-3xl bg-card border border-border p-8 sm:p-10 print:border-0 print:shadow-none print:p-0">
          {/* Print header */}
          <div className="flex items-center justify-between mb-8 pb-6 border-b border-border">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <span className="w-7 h-7 rounded-full bg-primary flex items-center justify-center">
                  <Sparkles className="w-3.5 h-3.5 text-primary-foreground" strokeWidth={1.5} />
                </span>
                <span className="font-heading text-lg text-primary">Vida Lab</span>
              </div>
              <h2 className="font-heading text-2xl text-primary">My Vida Health Snapshot</h2>
            </div>
            <div className="text-right text-sm text-muted-foreground">
              <p>{user?.full_name || user?.email || "Member"}</p>
              <p>Generated {new Date().toLocaleDateString()}</p>
            </div>
          </div>

          <p className="text-sm text-muted-foreground mb-6 leading-relaxed">
            Tracking period: <span className="text-primary font-medium">{new Date(snapshot.first).toLocaleDateString()}</span> – <span className="text-primary font-medium">{new Date(snapshot.last).toLocaleDateString()}</span> · {snapshot.total} check-ins
          </p>

          {/* Key metrics */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
            {[
              { label: "Avg energy", value: `${snapshot.avgEnergy}/5` },
              { label: "Avg sleep", value: snapshot.avgSleep ? `${snapshot.avgSleep}h` : "—" },
              { label: "Low-energy days", value: snapshot.lowEnergyDays },
              { label: "Poor-sleep days", value: snapshot.poorSleepDays },
            ].map((s) => (
              <div key={s.label} className="rounded-xl bg-background/50 border border-border p-4">
                <p className="text-xs uppercase tracking-widest text-muted-foreground">{s.label}</p>
                <p className="font-heading text-2xl text-primary mt-1">{s.value}</p>
              </div>
            ))}
          </div>

          {/* Most frequent symptoms */}
          {snapshot.topSymptoms.length > 0 && (
            <div className="mb-8">
              <h3 className="font-heading text-lg text-primary mb-3">Most frequent symptoms</h3>
              <div className="space-y-2">
                {snapshot.topSymptoms.map((s, i) => (
                  <div key={i} className="flex items-center justify-between text-sm border-b border-border/60 pb-2">
                    <span className="text-foreground">{s.symptom}</span>
                    <span className="text-muted-foreground">{s.count} {s.count === 1 ? "time" : "times"}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Mood summary */}
          {snapshot.topMoods.length > 0 && (
            <div className="mb-8">
              <h3 className="font-heading text-lg text-primary mb-3">Mood summary</h3>
              <div className="flex flex-wrap gap-2">
                {snapshot.topMoods.map((m, i) => (
                  <span key={i} className="text-sm px-3 py-1.5 rounded-full bg-background border border-border text-foreground">
                    {m.mood} <span className="text-muted-foreground">· {m.count}×</span>
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* Questions to consider */}
          <div className="rounded-2xl bg-accent/15 border border-accent/30 p-5">
            <h3 className="font-heading text-lg text-primary mb-3">Questions to consider asking</h3>
            <ul className="space-y-2">
              {snapshot.questions.map((q, i) => (
                <li key={i} className="text-sm text-foreground flex items-start gap-2.5">
                  <span className="text-accent-foreground/50 mt-1">·</span> {q}
                </li>
              ))}
            </ul>
          </div>

          <p className="text-xs text-muted-foreground mt-8 leading-relaxed">
            This snapshot summarizes self-reported wellness tracking from Vida Lab. It is not a medical record, a diagnosis, or a substitute for clinical advice. Please share it with your clinician as a conversation starter.
          </p>
        </div>
      )}

      <TreatmentLog />
      <AppointmentConcierge checkins={checkins} />
    </main>
  );
}