import React, { useState, useEffect, useMemo } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import { labelMood, labelSymptom } from "@/lib/insights";
import { Calendar, TrendingUp } from "lucide-react";
import Loader from "@/components/Loader";
import {
  ResponsiveContainer,
  LineChart,
  Line,
  AreaChart,
  Area,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ReferenceLine,
  Cell,
} from "recharts";

const MOOD_VALUES = {
  calm: 4, happy: 5, motivated: 4.5, neutral: 3,
  anxious: 2, irritable: 1.5, sad: 1,
};

const MOOD_COLORS = {
  happy: "#3c6b4f", motivated: "#5b8a6e", calm: "#87C0E4",
  neutral: "#a3b3a3", anxious: "#d4a574", irritable: "#c4906f", sad: "#a8412b",
};

function fmtDate(d) {
  return new Date(d).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

function ChartCard({ title, subtitle, children }) {
  return (
    <div className="rounded-3xl bg-card border border-border p-6 sm:p-8">
      <div className="mb-5">
        <h2 className="font-heading text-xl text-primary">{title}</h2>
        {subtitle && <p className="text-sm text-muted-foreground mt-0.5">{subtitle}</p>}
      </div>
      {children}
    </div>
  );
}

function StatCard({ label, value, sub }) {
  return (
    <div className="rounded-2xl bg-card border border-border p-5">
      <p className="text-xs uppercase tracking-widest text-muted-foreground">{label}</p>
      <p className="font-heading text-3xl text-primary mt-1">{value}</p>
      {sub && <p className="text-xs text-muted-foreground mt-1">{sub}</p>}
    </div>
  );
}

export default function Trends() {
  const { user } = useAuth();
  const [checkins, setCheckins] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    base44.entities.DailyCheckin.list("-checkin_date", 500)
      .then(setCheckins)
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const data = useMemo(() => {
    const now = new Date();
    const cutoff = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

    const recent = checkins
      .filter((c) => new Date(c.checkin_date) >= cutoff)
      .sort((a, b) => (a.checkin_date < b.checkin_date ? -1 : 1));

    if (recent.length === 0) return null;

    // Time-series data for energy + mood
    const series = recent.map((c) => ({
      date: fmtDate(c.checkin_date),
      Energy: c.energy,
      Mood: MOOD_VALUES[c.mood] ?? null,
      moodLabel: labelMood(c.mood),
      Sleep: c.sleep_hours,
      sleepQuality: c.sleep_quality,
    }));

    // Summary stats
    const avgEnergy = +(recent.reduce((s, c) => s + (c.energy || 0), 0) / recent.length).toFixed(1);
    const sleepEntries = recent.filter((c) => c.sleep_hours != null);
    const avgSleep = sleepEntries.length
      ? +(sleepEntries.reduce((s, c) => s + c.sleep_hours, 0) / sleepEntries.length).toFixed(1)
      : null;
    const sleepQualityEntries = recent.filter((c) => c.sleep_quality != null);
    const avgSleepQuality = sleepQualityEntries.length
      ? +(sleepQualityEntries.reduce((s, c) => s + c.sleep_quality, 0) / sleepQualityEntries.length).toFixed(1)
      : null;

    // Mood distribution
    const moodCounts = {};
    recent.forEach((c) => {
      const m = c.mood || "neutral";
      moodCounts[m] = (moodCounts[m] || 0) + 1;
    });
    const moodData = Object.entries(moodCounts)
      .map(([m, count]) => ({ mood: labelMood(m), count, fill: MOOD_COLORS[m] || "#a3b3a3" }))
      .sort((a, b) => b.count - a.count);

    const topMood = moodData[0]?.mood || "—";

    // Symptom frequency
    const symptomCounts = {};
    recent.forEach((c) => (c.symptoms || []).forEach((s) => {
      if (s !== "none") symptomCounts[s] = (symptomCounts[s] || 0) + 1;
    }));
    const topSymptoms = Object.entries(symptomCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([s, count]) => ({ symptom: labelSymptom(s), count }));

    // Trend direction (compare first half avg vs second half avg)
    const half = Math.floor(recent.length / 2);
    if (half >= 2) {
      const firstHalf = recent.slice(0, half);
      const secondHalf = recent.slice(half);
      const firstAvg = firstHalf.reduce((s, c) => s + (c.energy || 0), 0) / firstHalf.length;
      const secondAvg = secondHalf.reduce((s, c) => s + (c.energy || 0), 0) / secondHalf.length;
      var energyTrend = secondAvg > firstAvg + 0.3 ? "up" : secondAvg < firstAvg - 0.3 ? "down" : "steady";
    }

    return {
      series, avgEnergy, avgSleep, avgSleepQuality, moodData, topMood,
      topSymptoms, total: recent.length, energyTrend: energyTrend || "steady",
      first: recent[0].checkin_date, last: recent[recent.length - 1].checkin_date,
    };
  }, [checkins]);

  if (loading) {
    return <div className="flex justify-center py-24"><Loader /></div>;
  }

  return (
    <main className="max-w-5xl mx-auto px-5 sm:px-8 py-10">
      <div className="mb-10">
        <span className="text-xs uppercase tracking-widest text-muted-foreground">Trends · 90 days</span>
        <h1 className="font-heading text-4xl text-primary mt-1">Your long-term patterns</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">
          A wider view of how your energy, sleep, and mood have moved over the last three months — the kind of timeline that reveals seasonal shifts and slow-moving patterns.
        </p>
      </div>

      {!data ? (
        <div className="text-center py-20 rounded-2xl border border-dashed border-border">
          <Calendar className="w-10 h-10 text-muted-foreground mx-auto mb-4" strokeWidth={1} />
          <h2 className="font-heading text-2xl text-primary mb-2">No data yet</h2>
          <p className="text-muted-foreground">Start logging daily check-ins and your 90-day trends will appear here.</p>
        </div>
      ) : (
        <>
          {/* Summary stats */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
            <StatCard label="Avg energy" value={`${data.avgEnergy}/5`} sub={
              data.energyTrend === "up" ? "Trending up ↗" : data.energyTrend === "down" ? "Trending down ↘" : "Steady →"
            } />
            <StatCard label="Avg sleep" value={data.avgSleep ? `${data.avgSleep}h` : "—"} sub={data.avgSleepQuality ? `${data.avgSleepQuality}/5 quality` : ""} />
            <StatCard label="Most common mood" value={data.topMood} />
            <StatCard label="Check-ins" value={data.total} sub={`${fmtDate(data.first)} – ${fmtDate(data.last)}`} />
          </div>

          {/* Energy & Mood combined chart */}
          <div className="mb-6">
            <ChartCard title="Energy & mood" subtitle="Energy on a 1–5 scale; mood mapped to 1–5 for comparison (sad = 1, happy = 5)">
              <ResponsiveContainer width="100%" height={280}>
                <LineChart data={data.series} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(40 16% 89%)" vertical={false} />
                  <XAxis dataKey="date" tick={{ fontSize: 11, fill: "hsl(30 14% 55%)" }} tickLine={false} axisLine={{ stroke: "hsl(40 16% 89%)" }} interval="preserveStartEnd" minTickGap={28} />
                  <YAxis domain={[0, 5]} ticks={[0, 1, 2, 3, 4, 5]} tick={{ fontSize: 11, fill: "hsl(30 14% 55%)" }} tickLine={false} axisLine={false} />
                  <Tooltip
                    contentStyle={{ borderRadius: 12, border: "1px solid hsl(40 16% 89%)", fontSize: 13 }}
                    formatter={(value, name) => [name === "Energy" ? `${value}/5` : value, name]}
                  />
                  <ReferenceLine y={3} stroke="hsl(40 16% 89%)" strokeDasharray="2 2" />
                  <Line type="monotone" dataKey="Energy" stroke="#2E463E" strokeWidth={2} dot={false} activeDot={{ r: 5 }} connectNulls name="Energy" />
                  <Line type="monotone" dataKey="Mood" stroke="#87C0E4" strokeWidth={2} dot={false} activeDot={{ r: 5 }} connectNulls name="Mood" />
                </LineChart>
              </ResponsiveContainer>
              <div className="flex items-center gap-5 mt-3 text-xs text-muted-foreground">
                <span className="flex items-center gap-1.5"><span className="w-3 h-0.5 rounded bg-[#2E463E]" /> Energy</span>
                <span className="flex items-center gap-1.5"><span className="w-3 h-0.5 rounded bg-[#87C0E4]" /> Mood</span>
              </div>
            </ChartCard>
          </div>

          {/* Sleep chart */}
          <div className="mb-6">
            <ChartCard title="Sleep hours" subtitle="Hours slept per night — watch for patterns around stressful periods or cycle phases">
              <ResponsiveContainer width="100%" height={240}>
                <AreaChart data={data.series} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <defs>
                    <linearGradient id="sleepGrad" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#BDE0E9" stopOpacity={0.5} />
                      <stop offset="100%" stopColor="#BDE0E9" stopOpacity={0.05} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(40 16% 89%)" vertical={false} />
                  <XAxis dataKey="date" tick={{ fontSize: 11, fill: "hsl(30 14% 55%)" }} tickLine={false} axisLine={{ stroke: "hsl(40 16% 89%)" }} interval="preserveStartEnd" minTickGap={28} />
                  <YAxis domain={[0, 14]} ticks={[0, 4, 8, 12]} tick={{ fontSize: 11, fill: "hsl(30 14% 55%)" }} tickLine={false} axisLine={false} />
                  <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid hsl(40 16% 89%)", fontSize: 13 }} formatter={(v) => [`${v}h`, "Sleep"]} />
                  <ReferenceLine y={8} stroke="#3c6b4f" strokeDasharray="2 2" label={{ value: "8h target", fontSize: 10, fill: "#3c6b4f", position: "right" }} />
                  <Area type="monotone" dataKey="Sleep" stroke="#87C0E4" strokeWidth={2} fill="url(#sleepGrad)" connectNulls dot={false} activeDot={{ r: 5 }} />
                </AreaChart>
              </ResponsiveContainer>
            </ChartCard>
          </div>

          {/* Mood distribution */}
          <div className="mb-6">
            <ChartCard title="Mood distribution" subtitle="How your check-ins spread across moods over the past 90 days">
              <ResponsiveContainer width="100%" height={240}>
                <BarChart data={data.moodData} margin={{ top: 10, right: 10, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="hsl(40 16% 89%)" vertical={false} />
                  <XAxis dataKey="mood" tick={{ fontSize: 11, fill: "hsl(30 14% 55%)" }} tickLine={false} axisLine={{ stroke: "hsl(40 16% 89%)" }} />
                  <YAxis tick={{ fontSize: 11, fill: "hsl(30 14% 55%)" }} tickLine={false} axisLine={false} allowDecimals={false} />
                  <Tooltip contentStyle={{ borderRadius: 12, border: "1px solid hsl(40 16% 89%)", fontSize: 13 }} cursor={{ fill: "hsl(40 16% 93%)" }} />
                  <Bar dataKey="count" radius={[8, 8, 0, 0]} maxBarSize={56}>
                    {data.moodData.map((entry, i) => (
                      <Cell key={i} fill={entry.fill} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </ChartCard>
          </div>

          {/* Top symptoms */}
          {data.topSymptoms.length > 0 && (
            <div className="rounded-3xl bg-card border border-border p-6 sm:p-8">
              <h2 className="font-heading text-xl text-primary mb-1">Most frequent symptoms</h2>
              <p className="text-sm text-muted-foreground mb-5">Symptoms you've logged most often in the past 90 days</p>
              <div className="space-y-3">
                {data.topSymptoms.map((s, i) => {
                  const maxCount = data.topSymptoms[0].count;
                  const pct = Math.round((s.count / maxCount) * 100);
                  return (
                    <div key={i} className="flex items-center gap-4">
                      <div className="w-32 sm:w-40 shrink-0">
                        <span className="text-sm font-medium text-primary">{s.symptom}</span>
                      </div>
                      <div className="flex-1 h-8 rounded-lg bg-muted overflow-hidden">
                        <div className="h-full bg-accent rounded-lg flex items-center justify-end pr-2" style={{ width: `${pct}%` }}>
                          <span className="text-xs text-primary font-medium">{s.count}×</span>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          <div className="flex items-start gap-2.5 mt-8 text-sm text-muted-foreground bg-vida-blush/30 border border-vida-blush rounded-xl px-5 py-4">
            <TrendingUp className="w-4 h-4 text-primary mt-0.5 shrink-0" />
            <p>These charts show your self-reported wellness data over time. They're observations, not diagnoses — patterns worth noticing and bringing to a clinician, not conclusions.</p>
          </div>
        </>
      )}
    </main>
  );
}