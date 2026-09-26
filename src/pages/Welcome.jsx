import React, { useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import DailyCheckinForm from "@/components/DailyCheckinForm";
import StepIndicator from "@/components/welcome/StepIndicator";
import ProfileSetup from "@/components/welcome/ProfileSetup";
import GenderStep from "@/components/welcome/GenderStep";
import HealthConcernsStep from "@/components/welcome/HealthConcernsStep";
import { CheckCircle2, ArrowRight, LineChart, ClipboardList, TrendingUp } from "lucide-react";

const TOTAL_STEPS = 5;

export default function Welcome() {
  const { user } = useAuth();
  const [step, setStep] = useState(1);
  const [checkinDone, setCheckinDone] = useState(false);

  const handleCheckin = async (payload) => {
    await base44.entities.DailyCheckin.create(payload);
    setCheckinDone(true);
    setStep(5);
  };

  return (
    <main className="min-h-[80vh] flex items-center justify-center px-5 py-12">
      <div className="w-full max-w-2xl">
        <StepIndicator current={step} total={TOTAL_STEPS} />

        {/* Step 1: Gender selection */}
        {step === 1 && (
          <GenderStep onComplete={() => setStep(2)} />
        )}

        {/* Step 2: Health concerns */}
        {step === 2 && (
          <HealthConcernsStep onComplete={() => setStep(3)} />
        )}

        {/* Step 3: Profile setup (reminders) */}
        {step === 3 && (
          <ProfileSetup onComplete={() => setStep(4)} />
        )}

        {/* Step 4: First check-in */}
        {step === 4 && (
          <div className="max-w-2xl mx-auto">
            <div className="text-center mb-8">
              <div className="eyebrow mb-2">Step 4 · Your first check-in</div>
              <h2 className="font-heading text-3xl text-primary">Log how you're feeling today</h2>
              <p className="text-muted-foreground mt-2">This is the foundation of your Pattern Map. Two minutes now — patterns appear after a few weeks of entries.</p>
            </div>
            <div className="rounded-3xl bg-card border border-border p-6 sm:p-8">
              <DailyCheckinForm onSaved={handleCheckin} />
            </div>
          </div>
        )}

        {/* Step 5: Pattern Map intro */}
        {step === 5 && (
          <div className="text-center max-w-lg mx-auto">
            <div className="w-16 h-16 rounded-full bg-accent/20 flex items-center justify-center mx-auto mb-6">
              <CheckCircle2 className="w-7 h-7 text-primary" strokeWidth={1.5} />
            </div>
            <div className="eyebrow mb-2">Step 5 · You're all set</div>
            <h1 className="font-heading text-4xl text-primary mb-4">Your first pattern is logged</h1>
            <p className="text-muted-foreground leading-relaxed mb-8">
              Every check-in adds a dot to your Pattern Map. After a few weeks, you'll start seeing how your energy shifts, which symptoms cluster, and what your mood landscape looks like.
            </p>
            <div className="grid gap-3 mb-8 text-left">
              <Link to="/pattern-map" className="flex items-center gap-4 rounded-2xl bg-card border border-border p-5 hover:border-primary/30 transition-colors">
                <div className="w-10 h-10 rounded-xl bg-accent/20 flex items-center justify-center shrink-0">
                  <LineChart className="w-5 h-5 text-primary" strokeWidth={1.5} />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-primary">Open Pattern Map</p>
                  <p className="text-xs text-muted-foreground">See your correlations (needs 3+ check-ins to populate)</p>
                </div>
                <ArrowRight className="w-4 h-4 text-muted-foreground" />
              </Link>
              <Link to="/daily-signals" className="flex items-center gap-4 rounded-2xl bg-card border border-border p-5 hover:border-primary/30 transition-colors">
                <div className="w-10 h-10 rounded-xl bg-accent/20 flex items-center justify-center shrink-0">
                  <TrendingUp className="w-5 h-5 text-primary" strokeWidth={1.5} />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-primary">Go to Daily Signals</p>
                  <p className="text-xs text-muted-foreground">Your check-in home — log tomorrow here</p>
                </div>
                <ArrowRight className="w-4 h-4 text-muted-foreground" />
              </Link>
              <Link to="/doctor-prep" className="flex items-center gap-4 rounded-2xl bg-card border border-border p-5 hover:border-primary/30 transition-colors">
                <div className="w-10 h-10 rounded-xl bg-accent/20 flex items-center justify-center shrink-0">
                  <ClipboardList className="w-5 h-5 text-primary" strokeWidth={1.5} />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-primary">Try Doctor Prep</p>
                  <p className="text-xs text-muted-foreground">Turn check-ins into a printable health snapshot</p>
                </div>
                <ArrowRight className="w-4 h-4 text-muted-foreground" />
              </Link>
            </div>
            <Link
              to="/daily-signals"
              className="inline-flex items-center gap-2 rounded-full px-8 py-3.5 bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
            >
              Start using Vida+ <ArrowRight className="w-4 h-4" />
            </Link>
          </div>
        )}
      </div>
    </main>
  );
}