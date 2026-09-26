import React, { useState } from "react";
import { jsPDF } from "jspdf";
import { labelSymptom, labelMood } from "@/lib/insights";
import { useAuth } from "@/lib/AuthContext";
import { FileDown, Loader2, Lock } from "lucide-react";
import { toast } from "@/components/ui/use-toast";
import UpgradeButton from "@/components/UpgradeButton";

export default function PatternReportButton({ analysis, checkins, user }) {
  const { user: authUser } = useAuth();
  const isVidaPlus = authUser?.membership === "vida_plus";
  const [generating, setGenerating] = useState(false);

  if (!isVidaPlus) {
    return (
      <div className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-vida-blush bg-vida-blush/20 text-primary text-sm">
        <Lock className="w-4 h-4" strokeWidth={1.5} />
        <span className="hidden sm:inline">Pattern PDF —</span>
        <UpgradeButton
          className="!px-0 !py-0 !min-h-0 !bg-transparent !border-0 !text-primary text-sm font-medium hover:!bg-transparent !inline-flex !items-center"
        >
          Unlock with Vida+
        </UpgradeButton>
      </div>
    );
  }

  const generatePDF = async () => {
    if (!checkins || checkins.length === 0 || !analysis) {
      toast({ title: "Not enough data", description: "You need a few check-ins before generating a pattern report." });
      return;
    }
    setGenerating(true);
    await new Promise((r) => setTimeout(r, 50));

    try {
      const sorted = [...checkins].sort((a, b) => (a.checkin_date < b.checkin_date ? -1 : 1));
      const first = sorted[0].checkin_date;
      const last = sorted[sorted.length - 1].checkin_date;
      const parseLocalDate = (d) => new Date(d.slice(0, 10) + "T00:00:00");

      const doc = new jsPDF({ unit: "pt", format: "letter" });
      const pageWidth = doc.internal.pageSize.getWidth();
      const pageHeight = doc.internal.pageSize.getHeight();
      const margin = 50;
      const contentWidth = pageWidth - margin * 2;
      let y = margin;

      const ensureSpace = (needed) => {
        if (y + needed > pageHeight - margin) { doc.addPage(); y = margin; }
      };

      const FOREST = [46, 70, 62];
      const MOSS = [60, 107, 79];
      const SOFT = [90, 101, 94];
      const LINE = [232, 229, 223];
      const TAUPE = [117, 106, 89];
      const ACCENT = [143, 192, 228];

      // Header
      doc.setFont("helvetica", "bold");
      doc.setFontSize(22);
      doc.setTextColor(...FOREST);
      doc.text("VIDA LAB", margin, y);
      y += 26;

      doc.setFont("helvetica", "normal");
      doc.setFontSize(14);
      doc.text("Pattern Map Report", margin, y);
      y += 22;

      doc.setFontSize(9);
      doc.setTextColor(...SOFT);
      doc.text(user?.full_name || user?.email || "Member", margin, y);
      y += 12;
      doc.text(
        `Tracking period: ${parseLocalDate(first).toLocaleDateString()} – ${parseLocalDate(last).toLocaleDateString()}  ·  ${analysis.total} check-ins`,
        margin, y
      );
      y += 12;
      doc.text(`Generated ${new Date().toLocaleDateString()}`, margin, y);
      y += 18;

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
        `Average energy: ${analysis.avgEnergy}/5`,
        analysis.avgSleep != null ? `Average sleep: ${analysis.avgSleep}h` : null,
        `Total check-ins: ${analysis.total}`,
      ].filter(Boolean);
      stats.forEach((s) => { ensureSpace(14); doc.text(s, margin, y); y += 14; });
      y += 12;

      // Energy by cycle phase
      if (analysis.energyByPhase.length > 0) {
        ensureSpace(30);
        doc.setFont("helvetica", "bold");
        doc.setFontSize(13);
        doc.setTextColor(...FOREST);
        doc.text("Energy across your cycle", margin, y);
        y += 18;

        doc.setFontSize(10);
        doc.setTextColor(...SOFT);
        doc.setFont("helvetica", "normal");
        analysis.energyByPhase.forEach((p) => {
          ensureSpace(16);
          const barWidth = Math.round((p.energy / 5) * 200);
          doc.text(`${p.phase}`, margin, y);
          doc.setFillColor(...ACCENT);
          doc.roundedRect(margin + 90, y - 9, barWidth, 11, 2, 2, "F");
          doc.text(`${p.energy}/5  (${p.entries} entries)`, margin + 90 + barWidth + 8, y);
          y += 16;
        });
        y += 12;
      }

      // Symptom correlations
      if (analysis.correlations.length > 0) {
        ensureSpace(30);
        doc.setFont("helvetica", "bold");
        doc.setFontSize(13);
        doc.setTextColor(...FOREST);
        doc.text("Symptoms that cluster in a phase", margin, y);
        y += 18;

        doc.setFontSize(10);
        doc.setTextColor(...SOFT);
        doc.setFont("helvetica", "normal");
        analysis.correlations.forEach((c) => {
          ensureSpace(16);
          const barWidth = Math.round((c.pct / 100) * 250);
          doc.text(`${c.symptom}`, margin, y);
          doc.setTextColor(...MOSS);
          doc.text(`(${c.phase})`, margin + 120, y);
          doc.setFillColor(...MOSS);
          doc.roundedRect(margin + 200, y - 9, barWidth, 11, 2, 2, "F");
          doc.setTextColor(...SOFT);
          doc.text(`${c.pct}%  (${c.count}×)`, margin + 200 + barWidth + 8, y);
          y += 16;
        });
        y += 12;
      }

      // Mood distribution
      if (analysis.moodData.length > 0) {
        ensureSpace(30);
        doc.setFont("helvetica", "bold");
        doc.setFontSize(13);
        doc.setTextColor(...FOREST);
        doc.text("Mood landscape", margin, y);
        y += 18;

        doc.setFontSize(10);
        doc.setTextColor(...SOFT);
        doc.setFont("helvetica", "normal");
        const maxMood = Math.max(...analysis.moodData.map((m) => m.count));
        analysis.moodData.forEach((m) => {
          ensureSpace(16);
          const barWidth = Math.round((m.count / maxMood) * 250);
          doc.text(`${m.mood}`, margin, y);
          doc.setFillColor(...ACCENT);
          doc.roundedRect(margin + 90, y - 9, barWidth, 11, 2, 2, "F");
          doc.text(`${m.count}×`, margin + 90 + barWidth + 8, y);
          y += 16;
        });
        y += 12;
      }

      // Daily log table
      ensureSpace(30);
      doc.setFont("helvetica", "bold");
      doc.setFontSize(13);
      doc.setTextColor(...FOREST);
      doc.text("Daily log", margin, y);
      y += 16;

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
      sorted.forEach((c) => {
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

      // Disclaimer
      ensureSpace(50);
      doc.setDrawColor(...LINE);
      doc.line(margin, y, pageWidth - margin, y);
      y += 14;
      doc.setFontSize(8);
      doc.setTextColor(...TAUPE);
      const disclaimer =
        "This report summarizes self-reported wellness tracking from Vida Lab. It is not a medical record, a diagnosis, or a substitute for clinical advice. Pattern Map surfaces correlations in your own data — bring any concerns to a clinician.";
      const discLines = doc.splitTextToSize(disclaimer, contentWidth);
      discLines.forEach((line) => { ensureSpace(12); doc.text(line, margin, y); y += 12; });

      doc.save("vida-lab-pattern-map-report.pdf");
      toast({ title: "Report downloaded", description: "Your Pattern Map report has been saved as a PDF." });
    } catch (e) {
      console.error("PatternReportButton error:", e);
      toast({ title: "Could not generate report", description: "Something went wrong. Please try again.", variant: "destructive" });
    } finally {
      setGenerating(false);
    }
  };

  const disabled = generating || !checkins || checkins.length === 0 || !analysis;

  return (
    <button
      onClick={generatePDF}
      disabled={disabled}
      className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-border bg-card text-primary text-sm font-medium hover:border-primary/40 hover:bg-background transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
    >
      {generating ? <Loader2 className="w-4 h-4 animate-spin" /> : <FileDown className="w-4 h-4" />}
      {generating ? "Generating…" : "Download PDF report"}
    </button>
  );
}