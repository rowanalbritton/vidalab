import React, { useState } from "react";
import { base44 } from "@/api/base44Client";
import { Download, Loader2 } from "lucide-react";

const csvCell = (val) => {
  if (val === null || val === undefined) return "";
  const s = Array.isArray(val) ? val.join("; ") : String(val);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};

const section = (title, headers, rows) => {
  const line = `\n# ${title}\n`;
  if (!rows.length) return line + "(no records)\n";
  const head = headers.map(csvCell).join(",") + "\n";
  const body = rows
    .map((r) => headers.map((h) => csvCell(r[h])).join(","))
    .join("\n");
  return line + head + body + "\n";
};

export default function ExportHealthDataButton() {
  const [busy, setBusy] = useState(false);

  const handleExport = async () => {
    setBusy(true);
    try {
      const [checkins, treatments, experiments, logs, appointments] = await Promise.all([
        base44.entities.DailyCheckin.list("-checkin_date", 1000),
        base44.entities.Treatment.list("-created_date", 1000),
        base44.entities.Experiment.list("-created_date", 1000),
        base44.entities.ExperimentLog.list("-created_date", 1000),
        base44.entities.Appointment.list("-created_date", 1000),
      ]);

      const stamp = new Date().toISOString().slice(0, 10);
      const csv = [
        `VIDA LAB — Health History (exported ${stamp})`,
        section("Daily Check-ins", [
          "date", "energy", "sleep_hours", "sleep_quality", "mood",
          "pain_level", "cycle_phase", "symptoms", "practices", "notes", "insight",
        ], checkins.map((c) => ({
          date: c.checkin_date,
          energy: c.energy,
          sleep_hours: c.sleep_hours,
          sleep_quality: c.sleep_quality,
          mood: c.mood,
          pain_level: c.pain_level,
          cycle_phase: c.cycle_phase,
          symptoms: c.symptoms,
          practices: c.practices,
          notes: c.notes,
          insight: c.insight,
        }))),
        section("Treatments & Medications", [
          "name", "type", "status", "start_date", "end_date",
          "dosage", "effectiveness", "side_effects", "notes",
        ], treatments.map((t) => ({
          name: t.name,
          type: t.type,
          status: t.status,
          start_date: t.start_date,
          end_date: t.end_date,
          dosage: t.dosage,
          effectiveness: t.effectiveness,
          side_effects: t.side_effects,
          notes: t.notes,
        }))),
        section("Experiments", [
          "title", "intervention", "hypothesis", "status",
          "start_date", "end_date", "duration_days", "metrics", "results",
        ], experiments.map((e) => ({
          title: e.title,
          intervention: e.intervention,
          hypothesis: e.hypothesis,
          status: e.status,
          start_date: e.start_date,
          end_date: e.end_date,
          duration_days: e.duration_days,
          metrics: e.metrics_to_watch,
          results: e.results_summary,
        }))),
        section("Experiment Logs", [
          "experiment_id", "log_date", "adhered", "notes",
        ], logs.map((l) => ({
          experiment_id: l.experiment_id,
          log_date: l.log_date,
          adhered: l.adhered,
          notes: l.notes,
        }))),
        section("Appointments", [
          "date", "time", "doctor", "practice", "specialty",
          "reason", "status", "notes",
        ], appointments.map((a) => ({
          date: a.appointment_date,
          time: a.appointment_time,
          doctor: a.doctor_name,
          practice: a.practice_name,
          specialty: a.specialty,
          reason: a.reason,
          status: a.status,
          notes: a.notes,
        }))),
      ].join("\n");

      const blob = new Blob([csv], { type: "text/csv;charset=utf-8" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `vida-lab-health-history-${stamp}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error("Export failed", e);
      alert("We couldn't export your health data. Please try again.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <button
      onClick={handleExport}
      disabled={busy}
      className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-border text-primary text-sm font-medium hover:border-primary hover:bg-primary/5 transition-colors disabled:opacity-60"
    >
      {busy ? <Loader2 className="w-4 h-4 animate-spin" /> : <Download className="w-4 h-4" />}
      {busy ? "Preparing…" : "Export my data"}
    </button>
  );
}