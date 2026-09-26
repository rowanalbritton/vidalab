import React, { useState } from "react";
import { base44 } from "@/api/base44Client";
import { RefreshCw, FlaskConical, TrendingUp, AlertTriangle, Sparkles } from "lucide-react";
import Loader from "@/components/Loader";

const CONFIDENCE_STYLES = {
  low: { bg: "bg-vida-sage/20", text: "text-vida-moss", label: "Low confidence" },
  moderate: { bg: "bg-vida-sky/30", text: "text-[#416f8b]", label: "Moderate confidence" },
  high: { bg: "bg-vida-moss/15", text: "text-vida-moss", label: "High confidence" },
};

export default function ExperimentResults({ experiment, onResults }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // If results are already stored on the experiment, parse them.
  const storedResults = experiment.results_summary
    ? (() => { try { return JSON.parse(experiment.results_summary); } catch (_) { return null; } })()
    : null;

  const [results, setResults] = useState(storedResults);

  const loadResults = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await base44.functions.invoke("experiment-results", { experimentId: experiment.id });
      const d = res.data;
      if (d?.status === "ok" && d.results) {
        setResults(d.results);
        onResults?.(d.results);
      } else {
        setError("We couldn't analyze your experiment. Please try again.");
      }
    } catch (e) {
      setError("We couldn't analyze your experiment. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <Loader
        className="py-16"
        label="Analyzing your experiment data…"
      />
    );
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <AlertTriangle className="w-8 h-8 text-muted-foreground mx-auto mb-3" strokeWidth={1.5} />
        <p className="text-muted-foreground mb-5">{error}</p>
        <button
          onClick={loadResults}
          className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
        >
          <RefreshCw className="w-4 h-4" /> Try again
        </button>
      </div>
    );
  }

  if (!results) {
    return (
      <div className="text-center py-12">
        <div className="w-14 h-14 rounded-full bg-vida-sage/20 flex items-center justify-center mx-auto mb-4">
          <Sparkles className="w-6 h-6 text-vida-moss" strokeWidth={1.5} />
        </div>
        <h3 className="font-heading text-xl text-primary mb-2">Ready to analyze?</h3>
        <p className="text-sm text-muted-foreground mb-6 max-w-sm mx-auto">
          We'll compare your metrics on days you did the intervention vs days you didn't, and interpret the results.
        </p>
        <button
          onClick={loadResults}
          className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
        >
          <FlaskConical className="w-4 h-4" /> Analyze results
        </button>
      </div>
    );
  }

  const confidence = CONFIDENCE_STYLES[results.confidence] || CONFIDENCE_STYLES.low;

  return (
    <div className="space-y-5 animate-fade-in">
      {/* Verdict hero */}
      <div className="rounded-2xl bg-primary text-primary-foreground p-6 sm:p-8">
        <div className="flex items-center justify-between mb-3">
          <span className="text-xs uppercase tracking-widest text-vida-sky">Verdict</span>
          <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium ${confidence.bg} ${confidence.text}`}>
            {confidence.label}
          </span>
        </div>
        <p className="font-heading text-xl sm:text-2xl leading-snug text-balance">{results.verdict}</p>
      </div>

      {/* On vs Off summaries */}
      {(results.on_days_summary || results.off_days_summary) && (
        <div className="grid sm:grid-cols-2 gap-4">
          {results.on_days_summary && (
            <div className="rounded-2xl bg-vida-moss/10 border border-vida-moss/30 p-5">
              <p className="text-xs uppercase tracking-widest text-vida-moss mb-2">On days (did it)</p>
              <p className="text-sm text-muted-foreground leading-relaxed">{results.on_days_summary}</p>
            </div>
          )}
          {results.off_days_summary && (
            <div className="rounded-2xl bg-card border border-border p-5">
              <p className="text-xs uppercase tracking-widest text-muted-foreground mb-2">Off days (didn't)</p>
              <p className="text-sm text-muted-foreground leading-relaxed">{results.off_days_summary}</p>
            </div>
          )}
        </div>
      )}

      {/* Key findings */}
      {results.key_findings?.length > 0 && (
        <div className="rounded-2xl bg-card border border-border p-6">
          <div className="flex items-center gap-2 mb-4">
            <TrendingUp className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
            <h3 className="font-heading text-lg text-primary">Key findings</h3>
          </div>
          <ul className="space-y-3">
            {results.key_findings.map((f, i) => (
              <li key={i} className="flex items-start gap-2.5">
                <span className="w-1.5 h-1.5 rounded-full bg-vida-moss shrink-0 mt-2" />
                <p className="text-sm text-muted-foreground leading-relaxed">{f}</p>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Recommendations */}
      {results.recommendations?.length > 0 && (
        <div className="rounded-2xl bg-vida-sage/10 border border-vida-sage/30 p-6">
          <h3 className="font-heading text-lg text-primary mb-4">Next steps</h3>
          <div className="space-y-3">
            {results.recommendations.map((r, i) => (
              <div key={i} className="flex items-start gap-3">
                <span className="flex items-center justify-center w-6 h-6 rounded-full bg-vida-moss text-primary-foreground text-xs font-heading shrink-0">
                  {i + 1}
                </span>
                <p className="text-sm text-muted-foreground leading-relaxed pt-0.5">{r}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Disclaimer */}
      {results.disclaimer && (
        <p className="text-xs text-muted-foreground leading-relaxed border-t border-border pt-4">{results.disclaimer}</p>
      )}

      {/* Re-analyze */}
      <div className="flex justify-center">
        <button
          onClick={loadResults}
          className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-border text-muted-foreground text-sm hover:border-primary hover:text-primary transition-colors"
        >
          <RefreshCw className="w-4 h-4" /> Re-analyze
        </button>
      </div>
    </div>
  );
}