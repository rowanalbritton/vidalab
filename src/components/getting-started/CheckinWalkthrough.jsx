import React from "react";
import { Link } from "react-router-dom";
import { Calendar, Battery, Moon, Smile, Activity, ArrowRight } from "lucide-react";

const STEPS = [
  {
    icon: Calendar,
    title: "Open Daily Signals",
    text: "Found in the app menu. Each visit starts a fresh check-in for today.",
  },
  {
    icon: Battery,
    title: "Rate your energy",
    text: "From 1 (exhausted) to 5 (vibrant). One tap — no overthinking.",
  },
  {
    icon: Moon,
    title: "Log sleep & mood",
    text: "Hours slept, sleep quality, and how you're feeling. All quick picks.",
  },
  {
    icon: Activity,
    title: "Note symptoms & cycle",
    text: "Tap any that apply. Cycle phase helps surface hormonal patterns later.",
  },
  {
    icon: Smile,
    title: "Get your insight",
    text: "Each check-in returns a small, educational observation — not a diagnosis.",
  },
];

export default function CheckinWalkthrough() {
  return (
    <div>
      <div className="text-center mb-10">
        <div className="eyebrow mb-2">Your first check-in</div>
        <h2 className="font-heading text-3xl text-primary">Five taps, two minutes</h2>
        <p className="text-muted-foreground mt-2 max-w-lg mx-auto">
          Daily Signals is the heart of VIDA LAB. A few taps each day builds the dots that become your patterns.
        </p>
      </div>

      <div className="grid gap-3 mb-8">
        {STEPS.map((s, i) => (
          <div key={i} className="flex items-start gap-4 rounded-2xl bg-card border border-border p-5">
            <div className="w-10 h-10 rounded-xl bg-accent/20 flex items-center justify-center shrink-0">
              <s.icon className="w-5 h-5 text-primary" strokeWidth={1.5} />
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-xs font-heading text-muted-foreground">{String(i + 1).padStart(2, "0")}</span>
                <h3 className="text-sm font-medium text-primary">{s.title}</h3>
              </div>
              <p className="text-sm text-muted-foreground leading-relaxed">{s.text}</p>
            </div>
          </div>
        ))}
      </div>

      <Link
        to="/daily-signals"
        className="w-full inline-flex items-center justify-center gap-2 rounded-full px-8 py-3.5 bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
      >
        Try your first check-in <ArrowRight className="w-4 h-4" />
      </Link>
    </div>
  );
}