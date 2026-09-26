import React, { useState } from "react";
import { jsPDF } from "jspdf";
import { useAuth } from "@/lib/AuthContext";
import { FileDown, Loader2, Lock } from "lucide-react";
import { toast } from "@/components/ui/use-toast";
import UpgradeButton from "@/components/UpgradeButton";

// Strips common markdown formatting to plain text for PDF rendering.
function markdownToText(md) {
  if (!md) return "";
  return md
    .replace(/^### (.*$)/gm, "$1")
    .replace(/^## (.*$)/gm, "$1")
    .replace(/^# (.*$)/gm, "$1")
    .replace(/\*\*(.*?)\*\*/g, "$1")
    .replace(/\*(.*?)\*/g, "$1")
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, "$1 ($2)")
    .replace(/^[-*] (.*$)/gm, "  • $1")
    .replace(/^\d+\. (.*$)/gm, "  $1")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export default function ConditionPDFButton({ report }) {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";
  const [generating, setGenerating] = useState(false);

  const generatePDF = async () => {
    if (!report) return;
    setGenerating(true);
    await new Promise((r) => setTimeout(r, 50));

    try {
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

      const FOREST = [46, 70, 62];
      const MOSS = [60, 107, 79];
      const SOFT = [90, 101, 94];
      const LINE = [232, 229, 223];
      const TAUPE = [117, 106, 89];

      // Header
      doc.setFont("helvetica", "bold");
      doc.setFontSize(22);
      doc.setTextColor(...FOREST);
      doc.text("VIDA LAB", margin, y);
      y += 26;

      doc.setFont("helvetica", "normal");
      doc.setFontSize(14);
      doc.text("Condition Report", margin, y);
      y += 22;

      doc.setFontSize(9);
      doc.setTextColor(...SOFT);
      doc.text(`Generated ${new Date().toLocaleDateString()}`, margin, y);
      y += 18;

      doc.setDrawColor(...LINE);
      doc.line(margin, y, pageWidth - margin, y);
      y += 20;

      // Title
      doc.setFont("helvetica", "bold");
      doc.setFontSize(20);
      doc.setTextColor(...FOREST);
      const titleLines = doc.splitTextToSize(report.name, contentWidth);
      titleLines.forEach((line) => {
        ensureSpace(24);
        doc.text(line, margin, y);
        y += 24;
      });

      // Category
      doc.setFont("helvetica", "normal");
      doc.setFontSize(10);
      doc.setTextColor(...MOSS);
      doc.text(report.category?.replace(/_/g, " ").toUpperCase(), margin, y);
      y += 16;

      // Summary
      if (report.summary) {
        doc.setFontSize(11);
        doc.setTextColor(...SOFT);
        const summaryLines = doc.splitTextToSize(report.summary, contentWidth);
        summaryLines.forEach((line) => {
          ensureSpace(14);
          doc.text(line, margin, y);
          y += 14;
        });
        y += 12;
      }

      // Helper to render a markdown section
      const renderSection = (title, content) => {
        if (!content) return;
        ensureSpace(30);
        doc.setDrawColor(...LINE);
        doc.line(margin, y, pageWidth - margin, y);
        y += 16;
        doc.setFont("helvetica", "bold");
        doc.setFontSize(14);
        doc.setTextColor(...FOREST);
        doc.text(title, margin, y);
        y += 18;
        doc.setFont("helvetica", "normal");
        doc.setFontSize(10);
        doc.setTextColor(...SOFT);
        const text = markdownToText(content);
        const lines = doc.splitTextToSize(text, contentWidth);
        lines.forEach((line) => {
          ensureSpace(14);
          doc.text(line, margin, y);
          y += 14;
        });
        y += 12;
      };

      renderSection("Overview", report.overview);
      renderSection("Symptoms", report.symptoms);
      renderSection("Diagnosis", report.diagnosis);
      renderSection("Treatments", report.treatments);
      renderSection("Medical Resources", report.resources);

      // Conquer Plan
      if (report.doctors_guide || report.advocacy_guide || report.conquer_plan) {
        ensureSpace(30);
        doc.setDrawColor(...LINE);
        doc.line(margin, y, pageWidth - margin, y);
        y += 16;
        doc.setFont("helvetica", "bold");
        doc.setFontSize(14);
        doc.setTextColor(...FOREST);
        doc.text("The Conquer Plan", margin, y);
        y += 18;

        renderSection("Step 1 — Doctors to See", report.doctors_guide);
        renderSection("Step 2 — Advocate for Yourself", report.advocacy_guide);
        renderSection("Step 3 — Your Action Plan", report.conquer_plan);
      }

      // Disclaimer
      ensureSpace(50);
      doc.setDrawColor(...LINE);
      doc.line(margin, y, pageWidth - margin, y);
      y += 14;
      doc.setFontSize(8);
      doc.setTextColor(...TAUPE);
      const disclaimer =
        "This report is educational information, not medical advice. Always consult a qualified healthcare professional for diagnosis and treatment decisions.";
      const discLines = doc.splitTextToSize(disclaimer, contentWidth);
      discLines.forEach((line) => {
        ensureSpace(12);
        doc.text(line, margin, y);
        y += 12;
      });

      const filename = `vida-lab-${report.slug || report.name.toLowerCase().replace(/\s+/g, "-")}.pdf`;
      doc.save(filename);
      toast({ title: "Report saved", description: "Your condition report PDF has been downloaded." });
    } catch (e) {
      console.error("ConditionPDFButton error:", e);
      toast({ title: "Could not generate PDF", description: "Something went wrong. Please try again.", variant: "destructive" });
    } finally {
      setGenerating(false);
    }
  };

  if (!isVidaPlus) {
    return (
      <div className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-vida-blush bg-vida-blush/20 text-primary text-sm">
        <Lock className="w-4 h-4" strokeWidth={1.5} />
        <span className="hidden sm:inline">Save as PDF —</span>
        <UpgradeButton
          className="!px-0 !py-0 !min-h-0 !bg-transparent !border-0 !text-primary text-sm font-medium hover:!bg-transparent !inline-flex !items-center"
        >
          Unlock with Vida+
        </UpgradeButton>
      </div>
    );
  }

  return (
    <button
      onClick={generatePDF}
      disabled={generating || !report}
      className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-border bg-card text-primary text-sm font-medium hover:border-primary/40 hover:bg-background transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
    >
      {generating ? <Loader2 className="w-4 h-4 animate-spin" /> : <FileDown className="w-4 h-4" />}
      {generating ? "Generating…" : "Save as PDF"}
    </button>
  );
}