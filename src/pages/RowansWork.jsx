import React, { useEffect } from "react";
import { FileText } from "lucide-react";
import FavoriteButton from "@/components/FavoriteButton";

// Newest first. `anchor` gives each paper a stable link, e.g. /rowans-work#endometriosis-study.
// `id` matches the original research_papers row so existing favorites keep working.
const PAPERS = [
  {
    id: "db49613d-9ad4-4717-9e25-69212442519f",
    anchor: "endometriosis-study",
    program: "AP Research",
    year: "2025–2026",
    title: "The Systemic Neglect of Neuroimmune and Nervous System Manifestations in Adolescent Endometriosis: Psychosomatic and Stress-Related Consequences in Females Aged 14–21 in the United States",
    summary: "An original mixed-methods study (n=23, IRB-approved) at Lake Brantley High School, combining a researcher-developed Symptom Recognition and Validation Scale with the Perceived Stress Scale-10. 78% of participants reported that their symptoms had been dismissed as stress or “in their head,” and 91% reported that stress worsened their physical symptoms.",
    file_url: "https://lhorsiwwnqzkvunuazry.supabase.co/storage/v1/object/public/papers/Albritton_AP_Research_Endometriosis_Study.pdf",
  },
  {
    id: "417e135b-cf1c-4233-b90f-5066e3c3246e",
    anchor: "alzheimers-prevention",
    program: "AP Seminar",
    year: "2025",
    title: "Preventing Amyloid-Beta Plaque Accumulation in Genetically Predisposed Young Adults in the United States",
    summary: "Evaluates aerobic exercise, a Mediterranean-style diet, and sleep (glymphatic clearance) as a combined prevention strategy for APOE ε4 carriers, along with its limits.",
    file_url: "https://media.base44.com/files/public/6aacae7dbd22557932ef6597/9268e95fb_research-alzheimers.pdf",
  },
  {
    id: "5ef882e6-668e-4d9b-86ba-06d9a741fddc",
    anchor: "crispr-germline-editing",
    program: "AP Seminar",
    year: "2025",
    title: "CRISPR-Cas9 Technology in Germline Editing: A Scientific Evaluation",
    summary: "Explains how Cas9 makes targeted double-strand breaks and weighs therapeutic potential against off-target risk and the ethics of germline use.",
    file_url: "https://media.base44.com/files/public/6aacae7dbd22557932ef6597/5d2be9910_research-crispr.pdf",
  },
  {
    id: "ac10a16a-6c92-45e8-a954-0373a35dc20b",
    anchor: "burnout-work-life-balance",
    program: "AP Seminar",
    year: "2024",
    title: "From Burnout to Balance: Effective Solutions to Achieve Work-Life Balance for Adults in the U.S. Workforce",
    summary: "Compares corporate wellness programs with work-hour limits and recommends combining them.",
    file_url: "https://media.base44.com/files/public/6aacae7dbd22557932ef6597/fa36f4624_research-burnout.pdf",
  },
];

export default function RowansWork() {
  // ScrollToTop skips the first page load, so handle deep links like /rowans-work#endometriosis-study here.
  useEffect(() => {
    if (!window.location.hash) return;
    const id = decodeURIComponent(window.location.hash.slice(1));
    const timer = window.setTimeout(() => {
      document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
    }, 50);
    return () => window.clearTimeout(timer);
  }, []);

  return (
    <main>
      <header className="page-hero wrap">
        <div className="eyebrow">Rowan's Work</div>
        <h1>Original research behind VIDA LAB.</h1>
        <p>Before VIDA LAB was a platform, it was a research habit. These are the full papers — on Alzheimer's prevention, workplace burnout, and adolescent endometriosis — that shaped how this site thinks about evidence.</p>
      </header>

      <section className="section" style={{ paddingTop: "20px" }}>
        <div className="wrap">
          <div style={{ display: "grid", gap: 18, maxWidth: 760, margin: "0 auto" }}>
            {PAPERS.map((p) => (
              <article key={p.id} id={p.anchor} className="research-card" style={{ minHeight: "auto", position: "relative", scrollMarginTop: 150 }}>
                <FavoriteButton
                  resource={{
                    resource_id: p.id,
                    resource_title: p.title,
                    resource_category: p.program,
                    resource_type: "research_paper",
                    resource_url: p.file_url,
                    resource_subtitle: p.summary,
                  }}
                />
                <span className="stage">{p.program} · {p.year}</span>
                <h3 style={{ marginTop: 16 }}>{p.title}</h3>
                <p style={{ marginBottom: 20 }}>{p.summary}</p>
                <a href={p.file_url} target="_blank" rel="noopener noreferrer" className="card-link" style={{ display: "inline-flex", alignItems: "center", gap: 8 }}>
                  <FileText size={15} /> Read the full paper →
                </a>
              </article>
            ))}
          </div>
        </div>
      </section>
    </main>
  );
}
