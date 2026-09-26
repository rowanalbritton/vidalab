import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { base44 } from "@/api/base44Client";
import { Search } from "lucide-react";
import ExplainerLibrary from "@/components/ExplainerLibrary";
import FavoriteButton from "@/components/FavoriteButton";

const CATEGORIES = [
  { value: "all", label: "All" },
  { value: "autoimmune", label: "Autoimmune" },
  { value: "neurological", label: "Neurological" },
  { value: "dysautonomia", label: "Dysautonomia" },
  { value: "endocrine", label: "Endocrine" },
  { value: "chronic_pain", label: "Chronic Pain" },
  { value: "gynecological", label: "Gynecological" },
  { value: "musculoskeletal", label: "Musculoskeletal" },
  { value: "gastrointestinal", label: "Gastrointestinal" },
  { value: "respiratory", label: "Respiratory" },
  { value: "cardiovascular", label: "Cardiovascular" },
  { value: "mental_health", label: "Mental Health" },
];

export default function Library() {
  const [reports, setReports] = useState([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("all");

  useEffect(() => {
    (async () => {
      try {
        const data = await base44.entities.DiseaseReport.filter({ is_public: true }, "sort_order", 200);
        setReports(data);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const filtered = reports.filter((r) => {
    const matchesCat = category === "all" || r.category === category;
    const q = query.toLowerCase();
    const matchesQuery = !q ||
      r.name.toLowerCase().includes(q) ||
      (r.summary || "").toLowerCase().includes(q) ||
      (r.overview || "").toLowerCase().includes(q) ||
      (r.symptoms || "").toLowerCase().includes(q) ||
      (r.category || "").replace(/_/g, " ").toLowerCase().includes(q);
    return matchesCat && matchesQuery;
  });

  return (
    <main>
      <header className="page-hero wrap">
        <div className="eyebrow">The VIDA LAB Library</div>
        <h1>Chronic conditions, explained.</h1>
        <p>An ever-growing library of chronic illness reports — what the science says, where to find trusted medical resources, and a step-by-step plan to help you conquer your condition.</p>
        <div className="callout" style={{ marginTop: 30, maxWidth: 760, marginLeft: 0 }}>
          <p style={{ margin: 0, fontSize: 14, color: "var(--soft)" }}>
            <strong style={{ color: "var(--forest)" }}>Medical disclaimer:</strong> VIDA LAB is an educational platform created by a student researcher, not a licensed medical doctor. These reports are for learning and empowerment — not diagnosis or treatment. Always consult a qualified healthcare professional for medical decisions.
          </p>
        </div>
      </header>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="wrap">
          <div style={{ position: "relative", marginBottom: 30 }}>
            <Search size={18} style={{ position: "absolute", left: 18, top: "50%", transform: "translateY(-50%)", color: "var(--soft)" }} />
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search for a condition..."
              style={{ width: "100%", border: "1px solid var(--line)", borderRadius: 100, padding: "15px 20px 15px 50px", background: "var(--paper)", color: "var(--ink)", outline: "none", fontSize: 16 }}
            />
          </div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 40 }}>
            {CATEGORIES.map((c) => (
              <button
                key={c.value}
                onClick={() => setCategory(c.value)}
                style={{
                  padding: "9px 16px",
                  borderRadius: 100,
                  border: `1px solid ${category === c.value ? "var(--forest)" : "var(--line)"}`,
                  background: category === c.value ? "var(--forest)" : "transparent",
                  color: category === c.value ? "var(--cream)" : "var(--soft)",
                  cursor: "pointer",
                  fontSize: 13,
                  transition: "all .2s",
                }}
              >
                {c.label}
              </button>
            ))}
          </div>

          {loading ? (
            <p style={{ color: "var(--soft)" }}>Loading the library…</p>
          ) : filtered.length === 0 ? (
            <div style={{ textAlign: "center", padding: "60px 20px" }}>
              <p style={{ fontSize: 18, color: "var(--forest)", marginBottom: 8 }}>No conditions found{query ? ` for “{query}”` : ""}.</p>
              <p style={{ fontSize: 14, color: "var(--soft)" }}>We add new reports regularly — check back soon, or <Link to="/sasha" style={{ color: "var(--moss)", textDecoration: "underline" }}>ask Vida</Link> about your condition.</p>
            </div>
          ) : (
            <>
              <p style={{ color: "var(--soft)", fontSize: 14, marginBottom: 20 }}>{filtered.length} {filtered.length === 1 ? "report" : "reports"} found</p>
              <div className="substack-grid">
                {filtered.map((r) => (
                  <Link key={r.id} to={`/library/${r.slug}`} className="research-card" style={{ minHeight: 220, position: "relative" }}>
                    <FavoriteButton
                      resource={{
                        resource_id: r.id,
                        resource_title: r.name,
                        resource_category: r.category,
                        resource_type: "disease",
                        resource_url: `/library/${r.slug}`,
                        resource_subtitle: r.summary,
                      }}
                    />
                    <span className="stage">{r.category.replace(/_/g, " ")}</span>
                    <h3 style={{ marginTop: 14, fontSize: 22 }}>{r.name}</h3>
                    <p>{r.summary}</p>
                    <span className="card-link">Read the full report →</span>
                  </Link>
                ))}
              </div>
            </>
          )}
        </div>
      </section>

      <section className="section" style={{ paddingTop: 60, paddingBottom: 60 }}>
        <div className="wrap">
          <ExplainerLibrary />
        </div>
      </section>

      <section className="section" style={{ paddingTop: 40, background: "var(--paper)", borderTop: "1px solid var(--line)" }}>
        <div className="wrap" style={{ textAlign: "center" }}>
          <div className="eyebrow">Don’t see your condition?</div>
          <h2 style={{ fontSize: "clamp(28px,4vw,42px)", margin: "12px 0 20px" }}>We’re building the library every week.</h2>
          <p style={{ color: "var(--soft)", maxWidth: 520, margin: "0 auto 30px" }}>In the meantime, ask Vida your questions — she can explain research, symptoms, and terminology in plain language.</p>
          <Link className="button" to="/sasha">Ask Vida →</Link>
        </div>
      </section>
    </main>
  );
}