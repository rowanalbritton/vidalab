import React, { useMemo } from "react";
import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ReferenceLine,
} from "recharts";

const MOOD_VALUES = {
  calm: 4,
  happy: 5,
  motivated: 4.5,
  neutral: 3,
  anxious: 2,
  irritable: 1.5,
  sad: 1,
};

const MOOD_LABELS = {
  calm: "Calm",
  happy: "Happy",
  motivated: "Motivated",
  neutral: "Neutral",
  anxious: "Anxious",
  irritable: "Irritable",
  sad: "Sad",
};

function formatDate(d) {
  return new Date(d.slice(0, 10) + "T00:00:00").toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export default function MoodEnergyChart({ checkins }) {
  const data = useMemo(() => {
    const now = new Date();
    const thirtyDaysAgo = new Date(now);
    thirtyDaysAgo.setDate(now.getDate() - 30);

    return checkins
      .filter((c) => new Date(c.checkin_date.slice(0, 10) + "T00:00:00") >= thirtyDaysAgo)
      .sort((a, b) => (a.checkin_date < b.checkin_date ? -1 : 1))
      .map((c) => ({
        date: formatDate(c.checkin_date),
        rawDate: c.checkin_date,
        Energy: c.energy,
        Mood: MOOD_VALUES[c.mood] ?? null,
        moodLabel: MOOD_LABELS[c.mood] ?? c.mood,
      }));
  }, [checkins]);

  if (data.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
        Log a few check-ins to see your mood and energy trend over the last month.
      </div>
    );
  }

  const CustomTooltip = ({ active, payload }) => {
    if (!active || !payload || !payload.length) return null;
    const point = payload[0].payload;
    return (
      <div className="rounded-lg bg-card border border-border px-3 py-2 shadow-sm text-xs">
        <p className="font-medium text-primary mb-1">{point.date}</p>
        <p className="text-muted-foreground">Energy: <span className="font-medium text-primary">{point.Energy}/5</span></p>
        <p className="text-muted-foreground">Mood: <span className="font-medium text-primary">{point.moodLabel}</span></p>
      </div>
    );
  };

  return (
    <div className="rounded-2xl bg-card border border-border p-5 sm:p-6">
      <div className="flex items-baseline justify-between mb-4">
        <h3 className="font-heading text-lg text-primary">Last 30 days</h3>
        <span className="text-xs text-muted-foreground">{data.length} check-ins</span>
      </div>
      <div style={{ width: "100%", height: 240 }}>
        <ResponsiveContainer>
          <LineChart data={data} margin={{ top: 5, right: 10, left: -20, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" vertical={false} />
            <XAxis
              dataKey="date"
              tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }}
              tickLine={false}
              axisLine={{ stroke: "hsl(var(--border))" }}
              interval="preserveStartEnd"
              minTickGap={24}
            />
            <YAxis
              domain={[0, 5]}
              ticks={[0, 1, 2, 3, 4, 5]}
              tick={{ fontSize: 11, fill: "hsl(var(--muted-foreground))" }}
              tickLine={false}
              axisLine={false}
            />
            <Tooltip content={<CustomTooltip />} />
            <Legend
              wrapperStyle={{ fontSize: 12, paddingTop: 8 }}
              iconType="line"
            />
            <ReferenceLine y={3} stroke="hsl(var(--border))" strokeDasharray="2 2" />
            <Line
              type="monotone"
              dataKey="Energy"
              stroke="#2E463E"
              strokeWidth={2}
              dot={{ r: 3, fill: "#2E463E" }}
              activeDot={{ r: 5 }}
              connectNulls
            />
            <Line
              type="monotone"
              dataKey="Mood"
              stroke="#87C0E4"
              strokeWidth={2}
              dot={{ r: 3, fill: "#87C0E4" }}
              activeDot={{ r: 5 }}
              connectNulls
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
      <p className="text-xs text-muted-foreground mt-3 leading-relaxed">
        Mood is mapped to a 1–5 scale for visualization (sad = 1, happy = 5). Energy is your self-reported 1–5 level.
      </p>
    </div>
  );
}