import React, { useState, useEffect } from "react";
import { useParams, Link, Navigate } from "react-router-dom";
import { base44 } from "@/api/base44Client";
import ReactMarkdown from "react-markdown";
import { ArrowLeft } from "lucide-react";
import ConditionPDFButton from "@/components/ConditionPDFButton";
import FavoriteButton from "@/components/FavoriteButton";

export default function DiseaseDetail() {
  const { slug } = useParams();
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const results = await base44.entities.DiseaseReport.filter({ slug, is_public: true }, "sort_order", 1);
        setReport(results[0] || null);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    })();
  }, [slug]);

  if (loading) return <main className="wrap" style={{ padding: "100px 0" }}><p style={{ color: "var(--soft)" }}>Loading report…</p></main>;
  if (!report) return <Navigate to="/library" replace />;

  const hasConquer = report.doctors_guide || report.advocacy_guide || report.conquer_plan;

  return (
    <main>
      <header className="page-hero wrap">
        <Link to="/library" style={{ display: "inline-flex", alignItems: "center", gap: 8, color: "var(--soft)", fontSize: 14, marginBottom: 20 }}>
          <ArrowLeft size={16} /> Back to Library
        </Link>
        <div className="eyebrow">{report.category.replace(/_/g, " ")}</div>
        <h1>{report.name}</h1>
        <p style={{ fontSize: 20, color: "var(--soft)", maxWidth: 720 }}>{report.summary}</p>
        <div style={{ marginTop: 24, display: "flex", alignItems: "center", gap: 14, flexWrap: "wrap" }}>
          <ConditionPDFButton report={report} />
          <FavoriteButton
            variant="inline"
            size={20}
            resource={{
              resource_id: report.id,
              resource_title: report.name,
              resource_category: report.category,
              resource_type: "disease",
              resource_url: `/library/${report.slug}`,
              resource_subtitle: report.summary,
            }}
          />
          <span style={{ fontSize: 13, color: "var(--soft)" }}>Save to favorites</span>
        </div>
      </header>

      <div className="wrap">
        <div className="toc">
          <div className="eyebrow">In this report</div>
          <ol>
            {report.overview && <li><a href="#overview">Overview</a></li>}
            {report.symptoms && <li><a href="#symptoms">Symptoms</a></li>}
            {report.diagnosis && <li><a href="#diagnosis">Diagnosis</a></li>}
            {report.treatments && <li><a href="#treatments">Treatments</a></li>}
            {report.resources && <li><a href="#resources">Medical Resources</a></li>}
            {hasConquer && <li><a href="#conquer">The Conquer Plan</a></li>}
          </ol>
        </div>
      </div>

      <div className="wrap" style={{ maxWidth: 760, paddingBottom: 60 }}>
        <div className="prose">
          {report.overview && (
            <div id="overview">
              <h2>Overview</h2>
              <ReactMarkdown>{report.overview}</ReactMarkdown>
            </div>
          )}
          {report.symptoms && (
            <div id="symptoms">
              <h2>Symptoms</h2>
              <ReactMarkdown>{report.symptoms}</ReactMarkdown>
            </div>
          )}
          {report.diagnosis && (
            <div id="diagnosis">
              <h2>Diagnosis</h2>
              <ReactMarkdown>{report.diagnosis}</ReactMarkdown>
            </div>
          )}
          {report.treatments && (
            <div id="treatments">
              <h2>Treatments</h2>
              <ReactMarkdown>{report.treatments}</ReactMarkdown>
            </div>
          )}
          {report.resources && (
            <div id="resources">
              <h2>Medical Resources</h2>
              <ReactMarkdown>{report.resources}</ReactMarkdown>
            </div>
          )}

          {hasConquer && (
            <div id="conquer" style={{ marginTop: 58 }}>
              <h2>The Conquer Plan</h2>
              <p>A step-by-step guide to navigating your condition — from finding the right doctors to advocating for the care you deserve.</p>

              {report.doctors_guide && (
                <div className="callout">
                  <h3 style={{ marginTop: 0 }}>Step 1 — Doctors to See</h3>
                  <ReactMarkdown>{report.doctors_guide}</ReactMarkdown>
                </div>
              )}
              {report.advocacy_guide && (
                <div className="callout">
                  <h3 style={{ marginTop: 0 }}>Step 2 — Advocate for Yourself</h3>
                  <ReactMarkdown>{report.advocacy_guide}</ReactMarkdown>
                </div>
              )}
              {report.conquer_plan && (
                <div className="callout urgent">
                  <h3 style={{ marginTop: 0, color: "var(--cream)" }}>Step 3 — Your Action Plan</h3>
                  <ReactMarkdown>{report.conquer_plan}</ReactMarkdown>
                </div>
              )}
            </div>
          )}

          <div className="legal-end">
            <p><strong>Important:</strong> This report is educational information, not medical advice. Always consult a qualified healthcare professional for diagnosis and treatment decisions.</p>
          </div>
        </div>
      </div>

      <section className="section" style={{ paddingTop: 40 }}>
        <div className="wrap" style={{ textAlign: "center" }}>
          <div className="eyebrow">Have questions about your condition?</div>
          <h2 style={{ fontSize: "clamp(28px,4vw,42px)", margin: "12px 0 20px" }}>Talk to Vida.</h2>
          <p style={{ color: "var(--soft)", maxWidth: 520, margin: "0 auto 30px" }}>She can explain research, symptoms, and terminology in plain language — and point you toward VIDA LAB explainers.</p>
          <Link className="button" to="/sasha">Ask Vida →</Link>
        </div>
      </section>
    </main>
  );
}