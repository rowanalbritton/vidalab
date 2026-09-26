import React, { useMemo } from "react";
import {
  LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, ReferenceDot
} from "recharts";
import { TrendingUp, TrendingDown, Minus } from "lucide-react";

const MOOD_VALUES = {
  happy: 5, motivated: 4.5, calm: 4, neutral: 3, irritable: 2, anxious: 2, sad: 1,
};

const PRACTICE_LABELS = {
  meditation: "Meditation",
  gentle_exercise: "Gentle exercise",
  anti_inflammatory_meal: "Anti-inflammatory meal",
  supplement: "Supplement",
  breathing_exercise: "Breathing exercise",
  nature_time: "Nature time",
  sleep_hygiene: "Sleep hygiene",
  hydration: "Hydration",
  gratitude: "Gratitude",
  stretching: "Stretching",
};

export default function PracticeCorrelation({ checkins }) {
  const hasPractices = checkins.some((c) => c.practices && c.practices.length > 0);

  const chartData = useMemo(() => {
    return [...checkins]
      .sort((a, b) => (a.checkin_date < b.checkin_date ? -1 : 1))
      .slice(-30)
      .map((c) => ({
        date: new Date(c.checkin_date.split("T")[0] + "T00:00:00").toLocaleDateString(undefined, { month: "short", day: "numeric" }),
        mood: MOOD_VALUES[c.mood] ?? 3,
        pain: c.pain_level ?? 0,
        practices: c.practices || [],
      }));
  }, [checkins]);

  const correlations = useMemo(() => {
    if (!hasPractices) return [];
    const results = [];
    for (const [key, label] of Object.entries(PRACTICE_LABELS)) {
      const withP = checkins.filter((c) => c.practices?.includes(key));
      const withoutP = checkins.filter((c) => !c.practices?.includes(key));
      if (withP.length < 2) continue;

      const avgMoodWith = withP.reduce((s, c) => s + (MOOD_VALUES[c.mood] ?? 3), 0) / withP.length;
      const avgMoodWithout = withoutP.length > 0
        ? withoutP.reduce((s, c) => s + (MOOD_VALUES[c.mood] ?? 3), 0) / withoutP.length
        : null;
      const avgPainWith = withP.reduce((s, c) => s + (c.pain_level ?? 0), 0) / withP.length;
      const avgPainWithout = withoutP.length > 0
        ? withoutP.reduce((s, c) => s + (c.pain_level ?? 0), 0) / withoutP.length
        : null;

      results.push({
        key, label,
        count: withP.length,
        moodDiff: avgMoodWithout !== null ? avgMoodWith - avgMoodWithout : null,
        painDiff: avgPainWithout !== null ? avgPainWith - avgPainWithout : null,
      });
    }
    return results.filter((r) => r.moodDiff !== null);
  }, [checkins, hasPractices]);

  if (checkins.length < 3) return null;

  return (
    <div className="space-y-6">
      <div className="rounded-2xl bg-card border border-border p-6">
        <h3 className="font-heading text-xl text-primary mb-1">Mood &amp; Pain Trends</h3>
        <p className="text-sm text-muted-foreground mb-4">Last {Math.min(checkins.length, 30)} check-ins</p>
        <ResponsiveContainer width="100%" height={220}>
          <LineChart data={chartData} margin={{ top: 5, right: 10, left: -20, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E8E5DF" />
            <XAxis dataKey="date" tick={{ fontSize: 11, fill: "#756a59" }} interval="preserveStartEnd" />
            <YAxis yAxisId="mood" domain={[0, 5]} tick={{ fontSize: 11, fill: "#756a59" }} />
            <YAxis yAxisId="pain" orientation="right" domain={[0, 3]} tick={{ fontSize: 11, fill: "#756a59" }} />
            <Tooltip
              contentStyle={{ borderRadius: 12, border: "1px solid #E8E5DF", fontSize: 13 }}
              labelStyle={{ color: "#2E463E", fontWeight: 600 }}
            />
            <Line yAxisId="mood" type="monotone" dataKey="mood" stroke="#2E463E" strokeWidth={2} dot={false} name="Mood (1-5)" />
            <Line yAxisId="pain" type="monotone" dataKey="pain" stroke="#87C0E4" strokeWidth={2} dot={false} name="Pain (0-3)" />
          </LineChart>
        </ResponsiveContainer>
      </div>

      {correlations.length > 0 && (
        <div className="rounded-2xl bg-card border border-border p-6">
          <h3 className="font-heading text-xl text-primary mb-1">How Your Habits Affect Your Day</h3>
          <p className="text-sm text-muted-foreground mb-4">
            Average mood and pain on days with each practice vs. days without. Positive mood change and negative pain change are good.
          </p>
          <div className="grid sm:grid-cols-2 gap-3">
            {correlations.map((c) => (
              <div key={c.key} className="rounded-xl border border-border p-4">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-sm font-medium text-primary">{c.label}</span>
                  <span className="text-xs text-muted-foreground">{c.count} days</span>
                </div>
                <div className="flex gap-6 text-sm">
                  <div className="flex items-center gap-1.5">
                    <span className="text-muted-foreground">Mood</span>
                    {c.moodDiff > 0.15 ? (
                      <span className="text-green-600 font-medium flex items-center gap-0.5">
                        <TrendingUp className="w-3.5 h-3.5" /> +{c.moodDiff.toFixed(1)}
                      </span>
                    ) : c.moodDiff < -0.15 ? (
                      <span className="text-red-500 font-medium flex items-center gap-0.5">
                        <TrendingDown className="w-3.5 h-3.5" /> {c.moodDiff.toFixed(1)}
                      </span>
                    ) : (
                      <span className="text-muted-foreground flex items-center gap-0.5">
                        <Minus className="w-3.5 h-3.5" /> ~0
                      </span>
                    )}
                  </div>
                  <div className="flex items-center gap-1.5">
                    <span className="text-muted-foreground">Pain</span>
                    {c.painDiff < -0.15 ? (
                      <span className="text-green-600 font-medium flex items-center gap-0.5">
                        <TrendingDown className="w-3.5 h-3.5" /> {c.painDiff.toFixed(1)}
                      </span>
                    ) : c.painDiff > 0.15 ? (
                      <span className="text-red-500 font-medium flex items-center gap-0.5">
                        <TrendingUp className="w-3.5 h-3.5" /> +{c.painDiff.toFixed(1)}
                      </span>
                    ) : (
                      <span className="text-muted-foreground flex items-center gap-0.5">
                        <Minus className="w-3.5 h-3.5" /> ~0
                      </span>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
          <p className="text-xs text-muted-foreground mt-4 italic">
            These are observational correlations from your own data, not medical advice. Many factors influence mood and pain — these patterns are starting points for curiosity, not conclusions.
          </p>
        </div>
      )}

      {!hasPractices && checkins.length >= 3 && (
        <div className="rounded-2xl bg-vida-blush/20 border border-vida-blush p-5 text-center">
          <p className="text-sm text-muted-foreground">
            <strong className="text-primary">Tip:</strong> Tag the wellness practices you do each day in your check-in (meditation, gentle exercise, anti-inflammatory meals, and more). After a few days, you'll see how each habit correlates with your mood and pain right here.
          </p>
        </div>
      )}
    </div>
  );
}