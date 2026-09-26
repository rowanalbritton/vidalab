import React, { useState, useEffect, useMemo } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import MembershipGate from "@/components/MembershipGate";
import { labelSymptom, labelMood, labelCycle } from "@/lib/insights";
import { TrendingDown, TrendingUp, AlertCircle } from "lucide-react";
import SymptomHeatmap from "@/components/SymptomHeatmap";
import PatternReportButton from "@/components/PatternReportButton";
import Loader from "@/components/Loader";
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
  RadialBarChart, RadialBar, PolarAngleAxis,
} from "recharts";

const CYCLE_ORDER = ["menstrual", "follicular", "ovulation", "luteal"];

export default function PatternMap() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";
  const [checkins, setCheckins] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isVidaPlus) { setLoading(false); return; }
    base44.entities.DailyCheckin.list("-checkin_date", 500)
      .then(setCheckins)
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [isVidaPlus]);

  const analysis = useMemo(() => {
    if (!checkins.length) return null;

    // Symptom frequency (overall)
    const symptomCounts = {};
    checkins.forEach((c) => {
      (c.symptoms || []).forEach((s) => {
        if (s === "none") return;
        symptomCounts[s] = (symptomCounts[s] || 0) + 1;
      });
    });
    const topSymptoms = Object.entries(symptomCounts)
      .map(([symptom, count]) => ({ symptom: labelSymptom(symptom), count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 6);

    // Cycle phase analysis (only when the user is tracking)
    const byPhase = {};
    checkins.forEach((c) => {
      const p = c.cycle_phase || "not_tracking";
      if (p === "not_tracking") return;
      if (!byPhase[p]) byPhase[p] = { sum: 0, count: 0 };
      byPhase[p].sum += c.energy || 0;
      byPhase[p].count += 1;
    });
    const energyByPhase = CYCLE_ORDER.filter((p) => byPhase[p]).map((p) => ({
      phase: labelCycle(p),
      energy: +(byPhase[p].sum / byPhase[p].count).toFixed(1),
      entries: byPhase[p].count,
    }));

    const symptomByPhase = {};
    checkins.forEach((c) => {
      const p = c.cycle_phase || "not_tracking";
      if (p === "not_tracking") return;
      (c.symptoms || []).forEach((s) => {
        if (s === "none") return;
        const key = `${p}|${s}`;
        symptomByPhase[key] = (symptomByPhase[key] || 0) + 1;
      });
    });
    const correlations = Object.entries(symptomByPhase)
      .map(([key, count]) => {
        const [phase, symptom] = key.split("|");
        const phaseCount = byPhase[phase]?.count || 1;
        return { phase: labelCycle(phase), symptom: labelSymptom(symptom), count, pct: Math.round((count / phaseCount) * 100) };
      })
      .filter((c) => c.count >= 2)
      .sort((a, b) => b.pct - a.pct)
      .slice(0, 5);

    // Mood distribution
    const moodCounts = {};
    checkins.forEach((c) => {
      const m = c.mood || "neutral";
      moodCounts[m] = (moodCounts[m] || 0) + 1;
    });
    const moodData = Object.entries(moodCounts).map(([mood, count]) => ({
      mood: labelMood(mood), count, fill: "hsl(203 37% 75%)",
    }));

    // Sleep vs energy
    const sleepEnergy = checkins
      .filter((c) => c.sleep_hours != null && c.energy != null)
      .map((c) => ({ sleep: c.sleep_hours, energy: c.energy }));

    const avgSleep = sleepEnergy.length
      ? +(sleepEnergy.reduce((s, d) => s + d.sleep, 0) / sleepEnergy.length).toFixed(1)
      : null;
    const avgEnergy = +(checkins.reduce((s, c) => s + (c.energy || 0), 0) / checkins.length).toFixed(1);

    return { topSymptoms, energyByPhase, correlations, moodData, avgSleep, avgEnergy, total: checkins.length };
  }, [checkins]);

  if (!isVidaPlus) return <MembershipGate title="Your Pattern Map" />;
  if (loading) return <div className="flex justify-center py-24"><Loader /></div>;
  if (!analysis || checkins.length < 3) {
    return (
      <div className="max-w-2xl mx-auto px-5 sm:px-8 py-20 text-center">
        <AlertCircle className="w-10 h-10 text-muted-foreground mx-auto mb-4" strokeWidth={1} />
        <h2 className="font-heading text-2xl text-primary mb-2">Not enough dots yet</h2>
        <p className="text-muted-foreground">Pattern Map needs at least a few weeks of check-ins to surface correlations. Keep logging — your patterns will appear here.</p>
      </div>
    );
  }

  return (
    <main className="max-w-5xl mx-auto px-5 sm:px-8 py-10">
      <div className="mb-10">
        <span className="text-xs uppercase tracking-widest text-muted-foreground">Pattern Map · Vida+</span>
        <h1 className="font-heading text-4xl text-primary mt-1">Your correlations</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">Based on {analysis.total} check-ins. These are observations of your data, not diagnoses — patterns to bring to a clinician, not conclusions.</p>
        <div className="mt-5">
          <PatternReportButton analysis={analysis} checkins={checkins} user={user} />
        </div>
      </div>

      {/* Summary stats */}
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-10">
        <div className="rounded-2xl bg-card border border-border p-5">
          <p className="text-xs uppercase tracking-widest text-muted-foreground">Avg energy</p>
          <p className="font-heading text-3xl text-primary mt-1">{analysis.avgEnergy}/5</p>
        </div>
        {analysis.avgSleep != null && (
          <div className="rounded-2xl bg-card border border-border p-5">
            <p className="text-xs uppercase tracking-widest text-muted-foreground">Avg sleep</p>
            <p className="font-heading text-3xl text-primary mt-1">{analysis.avgSleep}h</p>
          </div>
        )}
        <div className="rounded-2xl bg-card border border-border p-5">
          <p className="text-xs uppercase tracking-widest text-muted-foreground">Check-ins</p>
          <p className="font-heading text-3xl text-primary mt-1">{analysis.total}</p>
        </div>
      </div>

      {/* Symptom intensity heatmap */}
      <SymptomHeatmap checkins={checkins} />

      {/* Energy by cycle phase (only when tracking) */}
      {analysis.energyByPhase.length > 0 && (
        <div className="rounded-3xl bg-card border border-border p-6 sm:p-8 mb-6">
          <h2 className="font-heading text-xl text-primary mb-1">Energy across your cycle</h2>
          <p className="text-sm text-muted-foreground mb-6">Average energy by phase — visible only when you're tracking your cycle.</p>
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={analysis.energyByPhase} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(40 18% 86%)" />
              <XAxis dataKey="phase" tick={{ fontSize: 12, fill: "hsl(30 14% 55%)" }} axisLine={false} tickLine={false} />
              <YAxis domain={[0, 5]} tick={{ fontSize: 12, fill: "hsl(30 14% 55%)" }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid hsl(40 18% 86%)", fontSize: 13 }} />
              <Bar dataKey="energy" fill="hsl(146 25% 23%)" radius={[8, 8, 0, 0]} maxBarSize={64} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Symptoms that cluster in a phase (only when tracking) */}
      {analysis.correlations.length > 0 && (
        <div className="rounded-3xl bg-card border border-border p-6 sm:p-8 mb-6">
          <h2 className="font-heading text-xl text-primary mb-1">Symptoms that cluster in a phase</h2>
          <p className="text-sm text-muted-foreground mb-6">Symptoms appearing repeatedly in the same cycle phase — the kind of pattern worth naming to a clinician.</p>
          <div className="space-y-3">
            {analysis.correlations.map((c, i) => (
              <div key={i} className="flex items-center gap-4">
                <div className="w-28 sm:w-40 shrink-0">
                  <span className="text-sm font-medium text-primary">{c.symptom}</span>
                  <p className="text-xs text-muted-foreground">{c.phase}</p>
                </div>
                <div className="flex-1 h-8 rounded-lg bg-muted overflow-hidden">
                  <div className="h-full bg-accent rounded-lg flex items-center justify-end pr-2" style={{ width: `${c.pct}%` }}>
                    <span className="text-xs text-primary font-medium">{c.pct}%</span>
                  </div>
                </div>
                <span className="text-xs text-muted-foreground w-16 text-right">{c.count}×</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Most frequent symptoms */}
      {analysis.topSymptoms.length > 0 && (
        <div className="rounded-3xl bg-card border border-border p-6 sm:p-8 mb-6">
          <h2 className="font-heading text-xl text-primary mb-1">Your most frequent symptoms</h2>
          <p className="text-sm text-muted-foreground mb-6">Symptoms that show up most often across your check-ins — the ones worth discussing with a clinician.</p>
          <div className="space-y-3">
            {analysis.topSymptoms.map((s, i) => (
              <div key={i} className="flex items-center gap-4">
                <div className="w-28 sm:w-40 shrink-0">
                  <span className="text-sm font-medium text-primary">{s.symptom}</span>
                </div>
                <div className="flex-1 h-8 rounded-lg bg-muted overflow-hidden">
                  <div className="h-full bg-accent rounded-lg flex items-center justify-end pr-2" style={{ width: `${(s.count / analysis.topSymptoms[0].count) * 100}%` }}>
                    <span className="text-xs text-primary font-medium">{s.count}×</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Mood distribution */}
      {analysis.moodData.length > 0 && (
        <div className="rounded-3xl bg-card border border-border p-6 sm:p-8">
          <h2 className="font-heading text-xl text-primary mb-1">Your mood landscape</h2>
          <p className="text-sm text-muted-foreground mb-6">How your check-ins distribute across moods.</p>
          <ResponsiveContainer width="100%" height={240}>
            <RadialBarChart innerRadius="20%" outerRadius="100%" data={analysis.moodData} startAngle={90} endAngle={-270}>
              <PolarAngleAxis type="number" domain={[0, Math.max(...analysis.moodData.map((d) => d.count))]} tick={false} />
              <RadialBar dataKey="count" cornerRadius={8} background={{ fill: "hsl(40 18% 90%)" }} />
              <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid hsl(40 18% 86%)", fontSize: 13 }} />
            </RadialBarChart>
          </ResponsiveContainer>
          <div className="flex flex-wrap gap-3 justify-center mt-4">
            {analysis.moodData.map((m) => (
              <span key={m.mood} className="text-xs text-muted-foreground flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-accent" /> {m.mood} ({m.count})
              </span>
            ))}
          </div>
        </div>
      )}

      <div className="flex items-start gap-2.5 mt-8 text-sm text-muted-foreground bg-vida-blush/30 border border-vida-blush rounded-xl px-5 py-4">
        <AlertCircle className="w-4 h-4 text-primary mt-0.5 shrink-0" />
        <p>Pattern Map surfaces correlations in your own data. It does not diagnose. If a pattern concerns you, bring it to a clinician — that's exactly what Doctor Prep is for.</p>
      </div>
    </main>
  );
}