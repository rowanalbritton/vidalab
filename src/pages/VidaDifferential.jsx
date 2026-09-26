import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { base44 } from "@/api/base44Client";
import { useAuth } from "@/lib/AuthContext";
import MembershipGate from "@/components/MembershipGate";
import {
  Compass,
  RefreshCw,
  AlertTriangle,
  ArrowLeft,
  Stethoscope,
  FlaskConical,
  Shield,
  TrendingUp,
  Sparkles,
} from "lucide-react";
import Loader from "@/components/Loader";

const STRENGTH_STYLES = {
  low: { bg: "bg-vida-sage/20", text: "text-vida-moss", label: "Worth exploring" },
  moderate: { bg: "bg-vida-sky/30", text: "text-[#416f8b]", label: "Moderate match" },
  high: { bg: "bg-vida-taupe/15", text: "text-vida-taupe", label: "Strong pattern match" },
};

export default function VidaDifferential() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [insufficientData, setInsufficientData] = useState(null);

  const loadDifferential = async () => {
    setLoading(true);
    setError(null);
    setInsufficientData(null);
    try {
      const res = await base44.functions.invoke("vida-differential", {});
      const d = res.data;
      if (d?.status === "insufficient_data") {
        setInsufficientData(d.message);
      } else if (d?.status === "ok" && d.differential) {
        setData(d);
      } else {
        setError("We couldn't generate your differential. Please try again.");
      }
    } catch (e) {
      setError("We couldn't generate your differential. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isVidaPlus) loadDifferential();
  }, [isVidaPlus]);

  if (!isVidaPlus) {
    return (
      <MembershipGate title="The Vida Differential is a Vida+ feature">
        Stuck or dismissed? The Vida Differential maps your patterns to conditions worth exploring —
        with the tests to ask for, the specialists to see, and how to advocate for yourself. Unlock it with Vida+.
      </MembershipGate>
    );
  }

  return (
    <main className="max-w-4xl mx-auto px-5 sm:px-8 py-10">
      {/* Header */}
      <div className="mb-8">
        <Link
          to="/daily-signals"
          className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" /> Back to Daily Signals
        </Link>
        <span className="text-xs uppercase tracking-widest text-muted-foreground">Vida+ Analysis</span>
        <h1 className="font-heading text-4xl text-primary mt-1">The Vida Differential</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">
          Your patterns mapped to conditions worth exploring — the tests to ask for, the specialists to see,
          and how to advocate for proper evaluation. Not a diagnosis. A starting point.
        </p>
      </div>

      {loading && (
        <Loader
          className="py-24"
          label="Analyzing your patterns and mapping conditions…"
        />
      )}

      {!loading && error && (
        <div className="text-center py-20">
          <AlertTriangle className="w-10 h-10 text-muted-foreground mx-auto mb-4" strokeWidth={1.5} />
          <p className="text-muted-foreground mb-6">{error}</p>
          <button
            onClick={loadDifferential}
            className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <RefreshCw className="w-4 h-4" /> Try again
          </button>
        </div>
      )}

      {!loading && insufficientData && (
        <div className="text-center py-20 max-w-md mx-auto">
          <div className="w-16 h-16 rounded-full bg-vida-sage/20 flex items-center justify-center mx-auto mb-5">
            <TrendingUp className="w-7 h-7 text-vida-moss" strokeWidth={1.5} />
          </div>
          <h2 className="font-heading text-2xl text-primary mb-3">Not enough data yet</h2>
          <p className="text-muted-foreground mb-6 leading-relaxed">{insufficientData}</p>
          <Link
            to="/daily-signals"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <Sparkles className="w-4 h-4" /> Check in now
          </Link>
        </div>
      )}

      {!loading && data?.differential && (
        <div className="space-y-8 animate-fade-in">
          {/* Summary hero */}
          <div className="rounded-3xl bg-primary text-primary-foreground p-8 sm:p-10">
            <div className="flex items-center gap-2 mb-4">
              <Compass className="w-5 h-5 text-vida-sky" strokeWidth={1.5} />
              <span className="text-xs uppercase tracking-widest text-vida-sky">Your differential</span>
            </div>
            <p className="font-heading text-2xl sm:text-3xl leading-snug text-balance">
              {data.differential.summary}
            </p>
            {data.generatedAt && (
              <p className="text-xs text-vida-sky/70 mt-4">
                Generated {new Date(data.generatedAt).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" })}
              </p>
            )}
          </div>

          {/* Patterns */}
          {data.differential.patterns?.length > 0 && (
            <div className="rounded-2xl bg-card border border-border p-6">
              <div className="flex items-center gap-2 mb-4">
                <TrendingUp className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
                <h3 className="font-heading text-xl text-primary">Patterns we're seeing</h3>
              </div>
              <ul className="space-y-3">
                {data.differential.patterns.map((pattern, i) => (
                  <li key={i} className="flex items-start gap-2.5">
                    <span className="w-1.5 h-1.5 rounded-full bg-vida-moss shrink-0 mt-2" />
                    <p className="text-sm text-muted-foreground leading-relaxed">{pattern}</p>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Differential cards */}
          {data.differential.differentials?.length > 0 && (
            <div>
              <h2 className="font-heading text-2xl text-primary mb-4">Conditions worth exploring</h2>
              <div className="space-y-4">
                {data.differential.differentials.map((diff, i) => {
                  const strength = STRENGTH_STYLES[diff.match_strength] || STRENGTH_STYLES.low;
                  return (
                    <div key={i} className="rounded-2xl bg-card border border-border p-6">
                      <div className="flex items-start justify-between gap-4 mb-4">
                        <h3 className="font-heading text-xl text-primary">{diff.condition}</h3>
                        <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-medium ${strength.bg} ${strength.text} shrink-0`}>
                          {strength.label}
                        </span>
                      </div>
                      <p className="text-sm text-muted-foreground leading-relaxed mb-5">{diff.why}</p>

                      {diff.tests_to_consider?.length > 0 && (
                        <div className="mb-4">
                          <div className="flex items-center gap-2 mb-2">
                            <FlaskConical className="w-4 h-4 text-vida-moss" strokeWidth={1.5} />
                            <p className="text-xs uppercase tracking-widest text-muted-foreground">Tests to consider</p>
                          </div>
                          <ul className="space-y-1.5">
                            {diff.tests_to_consider.map((t, j) => (
                              <li key={j} className="text-sm text-muted-foreground flex items-start gap-2">
                                <span className="text-vida-moss mt-1">·</span> {t}
                              </li>
                            ))}
                          </ul>
                        </div>
                      )}

                      {diff.specialists?.length > 0 && (
                        <div className="mb-4">
                          <div className="flex items-center gap-2 mb-2">
                            <Stethoscope className="w-4 h-4 text-vida-sky-deep" strokeWidth={1.5} />
                            <p className="text-xs uppercase tracking-widest text-muted-foreground">Specialists to see</p>
                          </div>
                          <div className="flex flex-wrap gap-2">
                            {diff.specialists.map((s, j) => (
                              <span key={j} className="text-sm rounded-full bg-muted px-3 py-1.5 text-foreground">
                                {s}
                              </span>
                            ))}
                          </div>
                        </div>
                      )}

                      {diff.red_flags?.length > 0 && (
                        <div className="rounded-xl bg-vida-clay/10 border border-vida-clay/20 p-4">
                          <div className="flex items-center gap-2 mb-2">
                            <AlertTriangle className="w-4 h-4 text-vida-clay" strokeWidth={1.5} />
                            <p className="text-xs uppercase tracking-widest text-vida-clay">Red flags — seek prompt evaluation</p>
                          </div>
                          <ul className="space-y-1.5">
                            {diff.red_flags.map((r, j) => (
                              <li key={j} className="text-sm text-vida-clay/80 flex items-start gap-2">
                                <span className="mt-1">·</span> {r}
                              </li>
                            ))}
                          </ul>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Advocacy notes */}
          {data.differential.advocacy_notes?.length > 0 && (
            <div className="rounded-2xl bg-vida-sage/10 border border-vida-sage/30 p-6">
              <div className="flex items-center gap-2 mb-4">
                <Shield className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
                <h3 className="font-heading text-xl text-primary">How to advocate for yourself</h3>
              </div>
              <ul className="space-y-3">
                {data.differential.advocacy_notes.map((note, i) => (
                  <li key={i} className="flex items-start gap-2.5">
                    <span className="w-1.5 h-1.5 rounded-full bg-vida-moss shrink-0 mt-2" />
                    <p className="text-sm text-muted-foreground leading-relaxed">{note}</p>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Next steps */}
          {data.differential.next_steps?.length > 0 && (
            <div className="rounded-2xl bg-card border border-border p-6">
              <h3 className="font-heading text-xl text-primary mb-4">Your next steps</h3>
              <div className="space-y-3">
                {data.differential.next_steps.map((step, i) => (
                  <div key={i} className="flex items-start gap-3">
                    <span className="flex items-center justify-center w-7 h-7 rounded-full bg-vida-moss text-primary-foreground text-sm font-heading shrink-0">
                      {i + 1}
                    </span>
                    <p className="text-sm text-muted-foreground leading-relaxed pt-0.5">{step}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Disclaimer */}
          {data.differential.disclaimer && (
            <p className="text-xs text-muted-foreground leading-relaxed max-w-2xl border-t border-border pt-5">
              {data.differential.disclaimer}
            </p>
          )}

          {/* Refresh */}
          <div className="flex justify-center pt-2">
            <button
              onClick={loadDifferential}
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-border text-muted-foreground text-sm hover:border-primary hover:text-primary transition-colors"
            >
              <RefreshCw className="w-4 h-4" /> Refresh analysis
            </button>
          </div>
        </div>
      )}
    </main>
  );
}