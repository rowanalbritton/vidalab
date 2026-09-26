import React, { useState, useEffect } from "react";
import { base44 } from "@/api/base44Client";
import {
  Stethoscope,
  Loader2,
  RefreshCw,
  AlertTriangle,
  MessageSquare,
  FileText,
  Shield,
  Package,
  TrendingUp,
  } from "lucide-react";
  import Loader from "@/components/Loader";

export default function AppointmentConcierge({ checkins }) {
  const [conditions, setConditions] = useState([]);
  const [selectedCondition, setSelectedCondition] = useState("");
  const [visitReason, setVisitReason] = useState("");
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [insufficientData, setInsufficientData] = useState(null);

  useEffect(() => {
    base44.entities.DiseaseReport.filter({ is_public: true }, "sort_order", 100)
      .then(setConditions)
      .catch(() => {});
  }, []);

  const generate = async () => {
    setLoading(true);
    setError(null);
    setInsufficientData(null);
    try {
      const res = await base44.functions.invoke("appointment-concierge", {
        conditionSlug: selectedCondition || null,
        visitReason: visitReason || null,
      });
      const d = res.data;
      if (d?.status === "insufficient_data") {
        setInsufficientData(d.message);
      } else if (d?.status === "ok" && d.prep) {
        setData(d);
      } else {
        setError("We couldn't generate your visit prep. Please try again.");
      }
    } catch (e) {
      setError("We couldn't generate your visit prep. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="mt-10">
      {/* Divider */}
      <div className="flex items-center gap-3 mb-6">
        <div className="flex-1 h-px bg-border" />
        <span className="text-xs uppercase tracking-widest text-muted-foreground">AI Visit Prep</span>
        <div className="flex-1 h-px bg-border" />
      </div>

      {/* Input form */}
      <div className="rounded-2xl bg-card border border-border p-6 mb-6">
        <div className="flex items-center gap-2 mb-4">
          <Stethoscope className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
          <h3 className="font-heading text-xl text-primary">Generate your visit prep</h3>
        </div>
        <p className="text-sm text-muted-foreground mb-5">
          Turn your tracking data into a personalized visit guide — a symptom narrative, questions to ask,
          tests to request, and an advocacy script so you're heard.
        </p>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-primary mb-1.5">
              Visiting for a specific condition? (optional)
            </label>
            <select
              value={selectedCondition}
              onChange={(e) => setSelectedCondition(e.target.value)}
              className="w-full rounded-xl border border-border bg-background px-4 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary"
            >
              <option value="">Not condition-specific</option>
              {conditions.map((c) => (
                <option key={c.id} value={c.slug}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-primary mb-1.5">
              What's this visit about? (optional)
            </label>
            <input
              type="text"
              value={visitReason}
              onChange={(e) => setVisitReason(e.target.value)}
              placeholder="e.g., I've been exhausted for 3 months and my doctor ruled out the basics"
              className="w-full rounded-xl border border-border bg-background px-4 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary"
            />
          </div>

          <button
            onClick={generate}
            disabled={loading}
            className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-50"
          >
            {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Stethoscope className="w-4 h-4" />}
            {loading ? "Generating…" : "Generate visit prep"}
          </button>
        </div>
      </div>

      {/* Loading */}
      {loading && (
        <Loader
          className="py-16"
          label="Preparing your visit guide…"
        />
      )}

      {/* Error */}
      {!loading && error && (
        <div className="text-center py-12">
          <AlertTriangle className="w-8 h-8 text-muted-foreground mx-auto mb-3" strokeWidth={1.5} />
          <p className="text-muted-foreground mb-5">{error}</p>
          <button
            onClick={generate}
            className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <RefreshCw className="w-4 h-4" /> Try again
          </button>
        </div>
      )}

      {/* Insufficient data */}
      {!loading && insufficientData && (
        <div className="text-center py-12 max-w-md mx-auto">
          <div className="w-14 h-14 rounded-full bg-vida-sage/20 flex items-center justify-center mx-auto mb-4">
            <TrendingUp className="w-6 h-6 text-vida-moss" strokeWidth={1.5} />
          </div>
          <p className="text-muted-foreground">{insufficientData}</p>
        </div>
      )}

      {/* Results */}
      {!loading && data?.prep && (
        <div className="space-y-5 animate-fade-in">
          {/* Visit summary */}
          <div className="rounded-2xl bg-primary text-primary-foreground p-6 sm:p-8">
            <span className="text-xs uppercase tracking-widest text-vida-sky">Visit summary</span>
            <p className="font-heading text-xl sm:text-2xl leading-snug mt-2 text-balance">
              {data.prep.visit_summary}
            </p>
          </div>

          {/* Symptom narrative */}
          {data.prep.symptom_narrative && (
            <div className="rounded-2xl bg-card border border-border p-6">
              <div className="flex items-center gap-2 mb-3">
                <MessageSquare className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
                <h3 className="font-heading text-lg text-primary">Your symptom narrative</h3>
              </div>
              <p className="text-sm text-muted-foreground leading-relaxed italic">
                "{data.prep.symptom_narrative}"
              </p>
            </div>
          )}

          {/* Key metrics */}
          {data.prep.key_metrics?.length > 0 && (
            <div className="rounded-2xl bg-card border border-border p-6">
              <h3 className="font-heading text-lg text-primary mb-4">Key metrics to share</h3>
              <div className="grid sm:grid-cols-2 gap-3">
                {data.prep.key_metrics.map((m, i) => (
                  <div key={i} className="rounded-xl bg-background border border-border p-4">
                    <p className="text-xs uppercase tracking-widest text-muted-foreground">{m.label}</p>
                    <p className="font-heading text-lg text-primary mt-1">{m.value}</p>
                    {m.context && <p className="text-xs text-muted-foreground mt-1">{m.context}</p>}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Questions to ask */}
          {data.prep.questions_to_ask?.length > 0 && (
            <div className="rounded-2xl bg-card border border-border p-6">
              <h3 className="font-heading text-lg text-primary mb-4">Questions to ask</h3>
              <ul className="space-y-3">
                {data.prep.questions_to_ask.map((q, i) => (
                  <li key={i} className="flex items-start gap-3">
                    <span className="flex items-center justify-center w-6 h-6 rounded-full bg-vida-moss text-primary-foreground text-xs font-heading shrink-0">
                      {i + 1}
                    </span>
                    <p className="text-sm text-muted-foreground leading-relaxed pt-0.5">{q}</p>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Tests to request */}
          {data.prep.tests_to_request?.length > 0 && (
            <div className="rounded-2xl bg-card border border-border p-6">
              <div className="flex items-center gap-2 mb-4">
                <FileText className="w-5 h-5 text-vida-sky-deep" strokeWidth={1.5} />
                <h3 className="font-heading text-lg text-primary">Tests worth asking about</h3>
              </div>
              <ul className="space-y-2">
                {data.prep.tests_to_request.map((t, i) => (
                  <li key={i} className="text-sm text-muted-foreground flex items-start gap-2">
                    <span className="text-vida-sky-deep mt-1">·</span> {t}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Advocacy script */}
          {data.prep.advocacy_script && (
            <div className="rounded-2xl bg-vida-sage/10 border border-vida-sage/30 p-6">
              <div className="flex items-center gap-2 mb-3">
                <Shield className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
                <h3 className="font-heading text-lg text-primary">If you're dismissed</h3>
              </div>
              <p className="text-sm text-muted-foreground leading-relaxed italic">
                "{data.prep.advocacy_script}"
              </p>
            </div>
          )}

          {/* What to bring */}
          {data.prep.what_to_bring?.length > 0 && (
            <div className="rounded-2xl bg-card border border-border p-6">
              <div className="flex items-center gap-2 mb-4">
                <Package className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
                <h3 className="font-heading text-lg text-primary">What to bring</h3>
              </div>
              <ul className="space-y-2">
                {data.prep.what_to_bring.map((item, i) => (
                  <li key={i} className="text-sm text-muted-foreground flex items-start gap-2">
                    <span className="text-vida-moss mt-1">·</span> {item}
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Disclaimer */}
          {data.prep.disclaimer && (
            <p className="text-xs text-muted-foreground leading-relaxed border-t border-border pt-4">
              {data.prep.disclaimer}
            </p>
          )}
        </div>
      )}
    </div>
  );
}