import React from "react";
import { Link } from "react-router-dom";
import { Sparkles, ArrowRight } from "lucide-react";
import CheckinWalkthrough from "@/components/getting-started/CheckinWalkthrough";
import PremiumInsights from "@/components/getting-started/PremiumInsights";

export default function GettingStarted() {
  return (
    <main className="max-w-2xl mx-auto px-5 sm:px-8 py-12 sm:py-16">
      {/* Welcome header */}
      <div className="text-center mb-16">
        <div className="w-16 h-16 rounded-full bg-accent/20 flex items-center justify-center mx-auto mb-6">
          <Sparkles className="w-7 h-7 text-primary" strokeWidth={1.5} />
        </div>
        <div className="eyebrow mb-2">Welcome to VIDA LAB</div>
        <h1 className="font-heading text-4xl text-primary mb-4">You're in. Here's what to do first.</h1>
        <p className="text-muted-foreground leading-relaxed max-w-lg mx-auto">
          Two things matter most: logging your first check-in, and knowing where your insights will appear. This quick guide covers both.
        </p>
      </div>

      {/* First check-in walkthrough */}
      <section className="mb-20">
        <CheckinWalkthrough />
      </section>

      {/* Premium insights */}
      <section className="mb-16">
        <PremiumInsights />
      </section>

      {/* Footer link */}
      <div className="text-center border-t border-border pt-8">
        <Link to="/daily-signals" className="text-sm text-primary font-medium hover:underline inline-flex items-center gap-1">
          Skip to Daily Signals <ArrowRight className="w-3.5 h-3.5" />
        </Link>
      </div>
    </main>
  );
}