import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { base44 } from "@/api/base44Client";
import { useAuth } from "@/lib/AuthContext";
import MembershipGate from "@/components/MembershipGate";
import {
  CloudRain,
  Sun,
  CloudSun,
  Cloud,
  Zap,
  Heart,
  AlertTriangle,
  Sparkles,
  RefreshCw,
  TrendingUp,
  Target,
  ArrowLeft,
} from "lucide-react";
import Loader from "@/components/Loader";

const RISK_STYLES = {
  low: { bg: "bg-vida-sage/20", text: "text-vida-moss", dot: "bg-vida-moss", label: "Low" },
  moderate: { bg: "bg-vida-sky/30", text: "text-[#416f8b]", dot: "bg-vida-sky-deep", label: "Moderate" },
  elevated: { bg: "bg-vida-taupe/15", text: "text-vida-taupe", dot: "bg-vida-taupe", label: "Elevated" },
  high: { bg: "bg-vida-clay/15", text: "text-vida-clay", dot: "bg-vida-clay", label: "High" },
};

const ENERGY_STYLES = {
  low: { icon: CloudRain, label: "Low energy", color: "text-vida-taupe" },
  moderate: { icon: CloudSun, label: "Steady", color: "text-vida-moss" },
  high: { icon: Sun, label: "High energy", color: "text-vida-sky-deep" },
};

function getRiskStyle(level) {
  return RISK_STYLES[level?.toLowerCase()] || RISK_STYLES.moderate;
}

function getEnergyStyle(level) {
  return ENERGY_STYLES[level?.toLowerCase()] || ENERGY_STYLES.moderate;
}

function ForecastDay({ day, isToday }) {
  const risk = getRiskStyle(day.risk_level);
  const energy = getEnergyStyle(day.energy);
  const EnergyIcon = energy.icon;

  return (
    <div
      className={`rounded-2xl border p-5 flex flex-col ${
        isToday ? "border-primary bg-card shadow-sm" : "border-border bg-card"
      }`}
    >
      <div className="flex items-center justify-between mb-3">
        <div>
          <p className="text-xs uppercase tracking-widest text-muted-foreground">{day.day}</p>
          {day.date && (
            <p className="text-xs text-muted-foreground mt-0.5">
              {new Date(day.date + "T00:00:00").toLocaleDateString(undefined, { month: "short", day: "numeric" })}
            </p>
          )}
        </div>
        <span className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ${risk.bg} ${risk.text}`}>
          <span className={`w-1.5 h-1.5 rounded-full ${risk.dot}`} />
          {risk.label}
        </span>
      </div>

      <div className="flex items-center gap-2 mb-3">
        <EnergyIcon className={`w-5 h-5 ${energy.color}`} strokeWidth={1.5} />
        <div>
          <p className="text-sm font-medium text-primary">{energy.label}</p>
          {day.mood && <p className="text-xs text-muted-foreground">{day.mood}</p>}
        </div>
      </div>

      <h3 className="font-heading text-lg text-primary leading-tight mb-2">{day.headline}</h3>
      <p className="text-sm text-muted-foreground leading-relaxed mb-4 flex-1">{day.why}</p>

      {day.risk_areas && day.risk_areas.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mb-3">
          {day.risk_areas.map((area, i) => (
            <span key={i} className="text-xs rounded-full bg-muted px-2.5 py-1 text-muted-foreground">
              {area}
            </span>
          ))}
        </div>
      )}

      {day.actions && day.actions.length > 0 && (
        <div className="space-y-1.5 pt-3 border-t border-border/60">
          {day.actions.map((action, i) => (
            <div key={i} className="flex items-start gap-2">
              <Sparkles className="w-3.5 h-3.5 text-vida-moss shrink-0 mt-0.5" strokeWidth={1.5} />
              <p className="text-xs text-muted-foreground leading-relaxed">{action}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default function BodyWeather() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [insufficientData, setInsufficientData] = useState(null);

  const loadForecast = async () => {
    setLoading(true);
    setError(null);
    setInsufficientData(null);
    try {
      const res = await base44.functions.invoke("body-weather-forecast", {});
      const d = res.data;
      if (d?.status === "insufficient_data") {
        setInsufficientData(d.message);
      } else if (d?.status === "ok" && d.forecast) {
        setData(d);
      } else if (d?.error === "Vida+ required") {
        // handled by isVidaPlus check
      } else {
        setError("We couldn't generate your forecast. Please try again.");
      }
    } catch (e) {
      setError("We couldn't generate your forecast. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!isVidaPlus) {
      setLoading(false);
      return;
    }
    loadForecast();
  }, [isVidaPlus]);

  if (!isVidaPlus) {
    return (
      <MembershipGate title="Body Weather is a Vida+ feature">
        Your Body Weather Forecast predicts energy, mood, and symptom risk for the week ahead — so you can act
        before patterns hit, not after. Unlock it with Vida+.
      </MembershipGate>
    );
  }

  return (
    <main className="max-w-6xl mx-auto px-5 sm:px-8 py-10">
      {/* Header */}
      <div className="mb-8">
        <Link
          to="/daily-signals"
          className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" /> Back to Daily Signals
        </Link>
        <span className="text-xs uppercase tracking-widest text-muted-foreground">Vida+ Forecast</span>
        <h1 className="font-heading text-4xl text-primary mt-1">Body Weather</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">
          Your week ahead, forecasted from your patterns. Like a weather report — for your body.
        </p>
      </div>

      {loading && (
        <Loader
          className="py-24"
          label="Reading your patterns and forecasting the week ahead…"
        />
      )}

      {!loading && error && (
        <div className="text-center py-20">
          <AlertTriangle className="w-10 h-10 text-muted-foreground mx-auto mb-4" strokeWidth={1.5} />
          <p className="text-muted-foreground mb-6">{error}</p>
          <button
            onClick={loadForecast}
            className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <RefreshCw className="w-4 h-4" /> Try again
          </button>
        </div>
      )}

      {!loading && insufficientData && (
        <div className="text-center py-20 max-w-md mx-auto">
          <div className="w-16 h-16 rounded-full bg-vida-sage/20 flex items-center justify-center mx-auto mb-5">
            <CloudSun className="w-7 h-7 text-vida-moss" strokeWidth={1.5} />
          </div>
          <h2 className="font-heading text-2xl text-primary mb-3">Not enough data yet</h2>
          <p className="text-muted-foreground mb-6 leading-relaxed">{insufficientData}</p>
          <Link
            to="/daily-signals"
            className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <Zap className="w-4 h-4" /> Check in now
          </Link>
        </div>
      )}

      {!loading && data?.forecast && (
        <div className="space-y-10 animate-fade-in">
          {/* Week summary hero */}
          <div className="rounded-3xl bg-primary text-primary-foreground p-8 sm:p-10">
            <div className="flex items-center gap-2 mb-4">
              <CloudSun className="w-5 h-5 text-vida-sky" strokeWidth={1.5} />
              <span className="text-xs uppercase tracking-widest text-vida-sky">This week's outlook</span>
            </div>
            <p className="font-heading text-2xl sm:text-3xl leading-snug text-balance">
              {data.forecast.summary}
            </p>
            {data.generatedAt && (
              <p className="text-xs text-vida-sky/70 mt-4">
                Forecast generated {new Date(data.generatedAt).toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" })}
              </p>
            )}
          </div>

          {/* 7-day forecast */}
          <div>
            <h2 className="font-heading text-2xl text-primary mb-4">7-day forecast</h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
              {data.forecast.forecast.map((day, i) => (
                <ForecastDay key={i} day={day} isToday={i === 0} />
              ))}
            </div>
          </div>

          {/* Patterns + triggers */}
          {data.forecast.patterns && data.forecast.patterns.length > 0 && (
            <div className="grid md:grid-cols-2 gap-6">
              <div className="rounded-2xl bg-card border border-border p-6">
                <div className="flex items-center gap-2 mb-4">
                  <TrendingUp className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
                  <h3 className="font-heading text-xl text-primary">Patterns we're seeing</h3>
                </div>
                <ul className="space-y-3">
                  {data.forecast.patterns.map((pattern, i) => (
                    <li key={i} className="flex items-start gap-2.5">
                      <span className="w-1.5 h-1.5 rounded-full bg-vida-moss shrink-0 mt-2" />
                      <p className="text-sm text-muted-foreground leading-relaxed">{pattern}</p>
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl bg-card border border-border p-6">
                <div className="flex items-center gap-2 mb-4">
                  <Target className="w-5 h-5 text-vida-sky-deep" strokeWidth={1.5} />
                  <h3 className="font-heading text-xl text-primary">Top triggers</h3>
                </div>
                <ul className="space-y-3">
                  {data.forecast.top_triggers?.map((trigger, i) => (
                    <li key={i} className="flex items-start gap-2.5">
                      <span className="w-1.5 h-1.5 rounded-full bg-vida-sky-deep shrink-0 mt-2" />
                      <p className="text-sm text-muted-foreground leading-relaxed">{trigger}</p>
                    </li>
                  ))}
                </ul>
              </div>
            </div>
          )}

          {/* Weekly actions */}
          {data.forecast.weekly_actions && data.forecast.weekly_actions.length > 0 && (
            <div className="rounded-2xl bg-vida-sage/10 border border-vida-sage/30 p-6 sm:p-8">
              <div className="flex items-center gap-2 mb-4">
                <Heart className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
                <h3 className="font-heading text-xl text-primary">This week, focus on</h3>
              </div>
              <div className="grid sm:grid-cols-3 gap-4">
                {data.forecast.weekly_actions.map((action, i) => (
                  <div key={i} className="flex items-start gap-3">
                    <span className="flex items-center justify-center w-7 h-7 rounded-full bg-vida-moss text-primary-foreground text-sm font-heading shrink-0">
                      {i + 1}
                    </span>
                    <p className="text-sm text-muted-foreground leading-relaxed pt-0.5">{action}</p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Disclaimer */}
          {data.forecast.disclaimer && (
            <p className="text-xs text-muted-foreground leading-relaxed max-w-2xl border-t border-border pt-5">
              {data.forecast.disclaimer}
            </p>
          )}

          {/* Refresh */}
          <div className="flex justify-center pt-2">
            <button
              onClick={loadForecast}
              className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-border text-muted-foreground text-sm hover:border-primary hover:text-primary transition-colors"
            >
              <RefreshCw className="w-4 h-4" /> Refresh forecast
            </button>
          </div>
        </div>
      )}
    </main>
  );
}