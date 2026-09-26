import React, { useState } from "react";
import { jsPDF } from "jspdf";
import { labelSymptom, labelMood } from "@/lib/insights";
import { useAuth } from "@/lib/AuthContext";
import { FileDown, Loader2, Lock } from "lucide-react";
import { toast } from "@/components/ui/use-toast";
import UpgradeButton from "@/components/UpgradeButton";

export default function MonthlyReportButton({ checkins, user }) {
  const { user: authUser } = useAuth();
  const isVidaPlus = authUser?.membership === "vida_plus";
  const [generating, setGenerating] = useState(false);

  if (!isVidaPlus) {
    return (
      <div className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-vida-blush bg-vida-blush/20 text-primary text-sm">
        <Lock className="w-4 h-4" strokeWidth={1.5} />
        <span className="hidden sm:inline">Monthly PDF —</span>
        <UpgradeButton
          className="!px-0 !py-0 !min-h-0 !bg-transparent !border-0 !text-primary text-sm font-medium hover:!bg-transparent !inline-flex !items-center"
        >
          Unlock with Vida+
        </UpgradeButton>
      </div>
    );
  }

  const generatePDF = async () => {
    if (!checkins || checkins.length === 0) {
      toast({ title: "No check-ins yet", description: "Log a few check-ins first to generate a monthly report." });
      return;
    }
    setGenerating(true);
    // Yield to the browser so React paints the loading spinner before the
    // heavy synchronous PDF generation blocks the main thread.
    await new Promise((r) => setTimeout(r, 50));

    try {
      // Filter to past 30 days
      const now = new Date();
      const cutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      const parseLocalDate = (d) => new Date(d.slice(0, 10) + "T00:00:00");
      const monthly = checkins
        .filter((c) => parseLocalDate(c.checkin_date) >= cutoff)
        .sort((a, b) => (a.checkin_date < b.checkin_date ? -1 : 1));

      if (monthly.length === 0) {
        toast({ title: "No recent data", description: "You don't have any check-ins from the last 30 days." });
        return;
      }

      const first = monthly[0].checkin_date;
      const last = monthly[monthly.length - 1].checkin_date;

      // Compute summary stats
      const avgEnergy = +(monthly.reduce((s, c) => s + (c.energy || 0), 0) / monthly.length).toFixed(1);
      const sleepEntries = monthly.filter((c) => c.sleep_hours != null);
      const avgSleep = sleepEntries.length
        ? +(sleepEntries.reduce((s, c) => s + c.sleep_hours, 0) / sleepEntries.length).toFixed(1)
        : null;
      const sleepQualityEntries = monthly.filter((c) => c.sleep_quality != null);
      const avgSleepQuality = sleepQualityEntries.length
        ? +(sleepQualityEntries.reduce((s, c) => s + c.sleep_quality, 0) / sleepQualityEntries.length).toFixed(1)
        : null;

      const moodCounts = {};
      monthly.forEach((c) => { const m = c.mood || "neutral"; moodCounts[m] = (moodCounts[m] || 0) + 1; });
      const topMoods = Object.entries(moodCounts).sort((a, b) => b[1] - a[1]).map(([m, c]) => ({ mood: labelMood(m), count: c }));

      const symptomCounts = {};
      monthly.forEach((c) => (c.symptoms || []).forEach((s) => { if (s !== "none") symptomCounts[s] = (symptomCounts[s] || 0) + 1; }));
      const topSymptoms = Object.entries(symptomCounts).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([s, c]) => ({ symptom: labelSymptom(s), count: c }));

      const painEntries = monthly.filter((c) => c.pain_level > 0);
      const avgPain = painEntries.length
        ? +(painEntries.reduce((s, c) => s + c.pain_level, 0) / painEntries.length).toFixed(1)
        : 0;

      const lowEnergyDays = monthly.filter((c) => c.energy <= 2).length;
      const poorSleepDays = monthly.filter((c) => c.sleep_quality != null && c.sleep_quality <= 2).length;

      // Suggested questions
      const questions = [];
      if (topSymptoms[0]) questions.push(`My "${topSymptoms[0].symptom}" appears frequently — is there anything worth investigating?`);
      if (lowEnergyDays >= 5) questions.push(`I've had ${lowEnergyDays} low-energy days in this window — could we look at possible causes?`);
      if (avgPain >= 2) questions.push(`My average pain on symptomatic days is moderate-to-severe — what's worth checking?`);
      if (poorSleepDays >= 5) questions.push(`Sleep quality has been low on ${poorSleepDays} days — any guidance on improving it?`);
      if (questions.length === 0) questions.push("Based on my tracking, is there anything I should be watching more closely?");

      // Build PDF
      const doc = new jsPDF({ unit: "pt", format: "letter" });
      const pageWidth = doc.internal.pageSize.getWidth();
      const pageHeight = doc.internal.pageSize.getHeight();
      const margin = 50;
      const contentWidth = pageWidth - margin * 2;
      let y = margin;

      const ensureSpace = (needed) => {
        if (y + needed > pageHeight - margin) {
          doc.addPage();
          y = margin;
        }
      };

      // Colors
      const FOREST = [46, 70, 62];
      const MOSS = [60, 107, 79];
      const SOFT = [90, 101, 94];
      const LINE = [232, 229, 223];
      const TAUPE = [117, 106, 89];
      const BLUSH = [232, 213, 207];

      // Header
      doc.setFont("helvetica", "bold");
      doc.setFontSize(22);
      doc.setTextColor(...FOREST);
      doc.text("VIDA LAB", margin, y);
      y += 26;

      doc.setFont("helvetica", "normal");
      doc.setFontSize(14);
      doc.text("Monthly Health Trends", margin, y);
      y += 22;

      doc.setFontSize(9);
      doc.setTextColor(...SOFT);
      doc.text(user?.full_name || user?.email || "Member", margin, y);
      y += 12;
      doc.text(
        `Tracking period: ${parseLocalDate(first).toLocaleDateString()} – ${parseLocalDate(last).toLocaleDateString()}  ·  ${monthly.length} check-ins`,
        margin, y
      );
      y += 12;
      doc.text(`Generated ${new Date().toLocaleDateString()}`, margin, y);
      y += 18;

      // Divider
      doc.setDrawColor(...LINE);
      doc.line(margin, y, pageWidth - margin, y);
      y += 20;

      // Summary stats
      doc.setFont("helvetica", "bold");
      doc.setFontSize(13);
      doc.setTextColor(...FOREST);
      doc.text("Summary", margin, y);
      y += 18;

      doc.setFontSize(10);
      doc.setTextColor(...SOFT);
      doc.setFont("helvetica", "normal");
      const stats = [
        `Average energy: ${avgEnergy}/5`,
        avgSleep ? `Average sleep: ${avgSleep}h` : "Average sleep: —",
        avgSleepQuality ? `Average sleep quality: ${avgSleepQuality}/5` : null,
        `Low-energy days (≤2): ${lowEnergyDays}`,
        `Poor-sleep days (≤2): ${poorSleepDays}`,
        painEntries.length > 0 ? `Average pain on symptomatic days: ${avgPain}/3` : null,
      ].filter(Boolean);
      stats.forEach((s) => {
        ensureSpace(14);
        doc.text(s, margin, y);
        y += 14;
      });
      y += 12;

      // Most frequent symptoms
      if (topSymptoms.length > 0) {
        ensureSpace(30);
        doc.setFont("helvetica", "bold");
        doc.setFontSize(13);
        doc.setTextColor(...FOREST);
        doc.text("Most frequent symptoms", margin, y);
        y += 18;

        doc.setFontSize(10);
        doc.setTextColor(...SOFT);
        doc.setFont("helvetica", "normal");
        topSymptoms.forEach((s) => {
          ensureSpace(14);
          doc.text(`${s.symptom} — ${s.count} ${s.count === 1 ? "time" : "times"}`, margin, y);
          y += 14;
        });
        y += 12;
      }

      // Mood summary
      if (topMoods.length > 0) {
        ensureSpace(30);
        doc.setFont("helvetica", "bold");
        doc.setFontSize(13);
        doc.setTextColor(...FOREST);
        doc.text("Mood summary", margin, y);
        y += 18;

        doc.setFontSize(10);
        doc.setTextColor(...SOFT);
        doc.setFont("helvetica", "normal");
        doc.text(topMoods.map((m) => `${m.mood} (${m.count}×)`).join("   ·   "), margin, y);
        y += 20;
      }

      // Daily log table
      ensureSpace(30);
      doc.setFont("helvetica", "bold");
      doc.setFontSize(13);
      doc.setTextColor(...FOREST);
      doc.text("Daily log", margin, y);
      y += 16;

      // Table header
      doc.setFontSize(8);
      doc.setTextColor(...MOSS);
      doc.setFont("helvetica", "bold");
      const colX = { date: margin, energy: margin + 100, sleep: margin + 170, mood: margin + 230, symptoms: margin + 320 };
      doc.text("DATE", colX.date, y);
      doc.text("ENERGY", colX.energy, y);
      doc.text("SLEEP", colX.sleep, y);
      doc.text("MOOD", colX.mood, y);
      doc.text("SYMPTOMS", colX.symptoms, y);
      y += 6;
      doc.setDrawColor(...LINE);
      doc.line(margin, y, pageWidth - margin, y);
      y += 12;

      doc.setFont("helvetica", "normal");
      doc.setFontSize(9);
      doc.setTextColor(...SOFT);
      monthly.forEach((c) => {
        ensureSpace(14);
        doc.text(parseLocalDate(c.checkin_date).toLocaleDateString(undefined, { month: "short", day: "numeric" }), colX.date, y);
        doc.text(`${c.energy || "—"}/5`, colX.energy, y);
        doc.text(c.sleep_hours != null ? `${c.sleep_hours}h` : "—", colX.sleep, y);
        doc.text(labelMood(c.mood), colX.mood, y);
        const syms = (c.symptoms || []).filter((s) => s !== "none").map(labelSymptom).join(", ") || "—";
        doc.text(syms.slice(0, 45), colX.symptoms, y);
        y += 14;
      });
      y += 14;

      // Suggested questions
      ensureSpace(30);
      doc.setFont("helvetica", "bold");
      doc.setFontSize(13);
      doc.setTextColor(...FOREST);
      doc.text("Questions to consider asking", margin, y);
      y += 18;

      doc.setFontSize(10);
      doc.setTextColor(...SOFT);
      doc.setFont("helvetica", "normal");
      questions.forEach((q) => {
        const lines = doc.splitTextToSize(`·  ${q}`, contentWidth);
        lines.forEach((line) => {
          ensureSpace(14);
          doc.text(line, margin, y);
          y += 14;
        });
      });
      y += 16;

      // Notes highlights
      const notesWithContent = monthly.filter((c) => c.notes && c.notes.trim());
      if (notesWithContent.length > 0) {
        ensureSpace(30);
        doc.setFont("helvetica", "bold");
        doc.setFontSize(13);
        doc.setTextColor(...FOREST);
        doc.text("Notes from the month", margin, y);
        y += 18;

        doc.setFontSize(9);
        doc.setTextColor(...SOFT);
        doc.setFont("helvetica", "normal");
        notesWithContent.slice(0, 10).forEach((c) => {
          const dateStr = parseLocalDate(c.checkin_date).toLocaleDateString(undefined, { month: "short", day: "numeric" });
          const noteLine = `${dateStr}: ${c.notes.trim()}`;
          const lines = doc.splitTextToSize(noteLine, contentWidth);
          lines.forEach((line) => {
            ensureSpace(12);
            doc.text(line, margin, y);
            y += 12;
          });
          y += 4;
        });
        y += 10;
      }

      // Disclaimer
      ensureSpace(50);
      doc.setDrawColor(...LINE);
      doc.line(margin, y, pageWidth - margin, y);
      y += 14;
      doc.setFontSize(8);
      doc.setTextColor(...TAUPE);
      const disclaimer =
        "This report summarizes self-reported wellness tracking from Vida Lab. It is not a medical record, a diagnosis, or a substitute for clinical advice. Please share it with your clinician as a conversation starter.";
      const discLines = doc.splitTextToSize(disclaimer, contentWidth);
      discLines.forEach((line) => {
        ensureSpace(12);
        doc.text(line, margin, y);
        y += 12;
      });

      doc.save("vida-lab-monthly-health-trends.pdf");
      toast({ title: "Report downloaded", description: "Your monthly health trends PDF has been saved." });
    } catch (e) {
      console.error("MonthlyReportButton error:", e);
      toast({ title: "Could not generate report", description: "Something went wrong. Please try again.", variant: "destructive" });
    } finally {
      setGenerating(false);
    }
  };

  const disabled = generating || !checkins || checkins.length === 0;

  return (
    <button
      onClick={generatePDF}
      disabled={disabled}
      className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-border bg-card text-primary text-sm font-medium hover:border-primary/40 hover:bg-background transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
    >
      {generating ? <Loader2 className="w-4 h-4 animate-spin" /> : <FileDown className="w-4 h-4" />}
      {generating ? "Generating…" : "Download monthly PDF"}
    </button>
  );
}