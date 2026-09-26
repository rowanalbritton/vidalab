import React from "react";
import { Link } from "react-router-dom";
import { useAuth } from "@/lib/AuthContext";
import { CloudSun, Lock, ArrowRight } from "lucide-react";

// Teaser card shown on Daily Signals to drive engagement with Body Weather.
// Vida+ members get a link to the full forecast; free members see an upgrade prompt.
export default function BodyWeatherCard() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";

  if (isVidaPlus) {
    return (
      <Link
        to="/body-weather"
        className="group block rounded-2xl bg-gradient-to-br from-vida-sky/20 via-vida-sage/10 to-transparent border border-vida-sky/40 p-5 mb-8 hover:border-vida-sky-deep/50 transition-colors"
      >
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-full bg-vida-sky/30 flex items-center justify-center shrink-0">
            <CloudSun className="w-6 h-6 text-vida-sky-deep" strokeWidth={1.5} />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-xs uppercase tracking-widest text-vida-moss font-medium">Vida+ Forecast</p>
            <h3 className="font-heading text-lg text-primary mt-0.5">Your Body Weather is ready</h3>
            <p className="text-sm text-muted-foreground mt-0.5">See your week ahead — predicted energy, mood, and flare risk.</p>
          </div>
          <ArrowRight className="w-5 h-5 text-muted-foreground group-hover:text-primary group-hover:translate-x-0.5 transition-all shrink-0" />
        </div>
      </Link>
    );
  }

  return (
    <Link
      to="/body-weather"
      className="group block rounded-2xl bg-card border border-dashed border-border p-5 mb-8 hover:border-primary/30 transition-colors"
    >
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 rounded-full bg-vida-blush flex items-center justify-center shrink-0">
          <Lock className="w-5 h-5 text-primary" strokeWidth={1.5} />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-xs uppercase tracking-widest text-vida-moss font-medium">Vida+ Feature</p>
          <h3 className="font-heading text-lg text-primary mt-0.5">Body Weather Forecast</h3>
          <p className="text-sm text-muted-foreground mt-0.5">Predict your week ahead — energy, mood, and flare risk before they hit.</p>
        </div>
        <ArrowRight className="w-5 h-5 text-muted-foreground group-hover:text-primary group-hover:translate-x-0.5 transition-all shrink-0" />
      </div>
    </Link>
  );
}