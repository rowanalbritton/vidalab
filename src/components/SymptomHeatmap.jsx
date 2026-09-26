import React, { useMemo } from "react";

function intensity(checkin) {
  if (!checkin) return 0;
  let score = 0;
  score += (checkin.symptoms || []).filter(s => s !== "none").length;
  score += checkin.pain_level || 0;
  if (checkin.energy && checkin.energy <= 2) score += 1;
  if (checkin.sleep_quality && checkin.sleep_quality <= 2) score += 1;
  return score;
}

const COLORS = ["#eef0ea", "#d4e0d2", "#a3b3a3", "#6b8e72", "#3c6b4f", "#2E463E"];

function colorFor(score, max) {
  if (score === 0) return "#eef0ea";
  const ratio = Math.min(score / Math.max(max, 1), 1);
  const idx = Math.min(Math.floor(ratio * (COLORS.length - 1)), COLORS.length - 1);
  return COLORS[idx];
}

function dateStr(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

const DOW = ["S", "M", "T", "W", "T", "F", "S"];

export default function SymptomHeatmap({ checkins }) {
  const { weeks, maxScore, monthLabels } = useMemo(() => {
    const map = {};
    checkins.forEach(c => {
      const d = c.checkin_date;
      if (!map[d]) map[d] = { score: 0, checkin: c };
      map[d].score = intensity(c);
    });

    const maxScore = Math.max(...Object.values(map).map(d => d.score), 1);

    const today = new Date();
    const start = new Date(today);
    start.setDate(start.getDate() - 83);
    start.setDate(start.getDate() - start.getDay());

    const weeks = [];
    const monthLabels = [];
    let currentMonth = -1;

    for (let w = 0; w < 12; w++) {
      const week = [];
      for (let dow = 0; dow < 7; dow++) {
        const d = new Date(start);
        d.setDate(d.getDate() + w * 7 + dow);
        const ds = dateStr(d);
        const entry = map[ds];
        const isFuture = d > today;

        if (dow === 0 && d.getMonth() !== currentMonth) {
          currentMonth = d.getMonth();
          monthLabels.push({ weekIndex: w, label: d.toLocaleDateString("en", { month: "short" }) });
        }

        week.push({ date: ds, score: entry?.score || 0, checkin: entry?.checkin, isFuture });
      }
      weeks.push(week);
    }

    return { weeks, maxScore, monthLabels };
  }, [checkins]);

  return (
    <div className="rounded-3xl bg-card border border-border p-6 sm:p-8 mb-6">
      <h2 className="font-heading text-xl text-primary mb-1">Symptom intensity heatmap</h2>
      <p className="text-sm text-muted-foreground mb-6">Each square is a day. Darker = more symptoms, higher pain, or lower energy. Hover for details.</p>

      <div className="flex gap-1 overflow-x-auto">
        <div className="flex flex-col gap-1 mr-1 shrink-0">
          <div className="h-3.5 w-3"></div>
          {DOW.map((d, i) => (
            <div key={i} className="h-3.5 w-3 text-[10px] text-muted-foreground flex items-center justify-center">{i % 2 === 1 ? d : ""}</div>
          ))}
        </div>

        <div className="shrink-0">
          <div className="flex gap-1 mb-1 h-4">
            {weeks.map((_, wi) => {
              const label = monthLabels.find(m => m.weekIndex === wi);
              return <div key={wi} className="w-3.5 text-[10px] text-muted-foreground">{label ? label.label : ""}</div>;
            })}
          </div>

          <div className="flex gap-1">
            {weeks.map((week, wi) => (
              <div key={wi} className="flex flex-col gap-1">
                {week.map((day, di) => (
                  <div
                    key={di}
                    title={day.checkin ? `${day.date}: intensity ${day.score}` : day.isFuture ? "" : `${day.date}: no check-in`}
                    className="w-3.5 h-3.5 rounded-[3px] transition-transform hover:scale-125 cursor-pointer"
                    style={{
                      backgroundColor: day.isFuture ? "transparent" : colorFor(day.score, maxScore),
                      border: day.score === 0 && !day.isFuture ? "1px solid #eef0ea" : "none",
                    }}
                  />
                ))}
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="flex items-center gap-2 mt-4 ml-7">
        <span className="text-xs text-muted-foreground">Less</span>
        {COLORS.map((c, i) => (
          <div key={i} className="w-3.5 h-3.5 rounded-[3px]" style={{ backgroundColor: c }} />
        ))}
        <span className="text-xs text-muted-foreground">More</span>
      </div>
    </div>
  );
}