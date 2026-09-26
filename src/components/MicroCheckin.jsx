import React, { useState } from "react";
import { Link } from "react-router-dom";
import { generateInsight } from "@/lib/insights";
import { Sparkles, ArrowRight, Zap, Moon, Smile } from "lucide-react";

const MOODS = [
  { value: "calm", label: "Calm" },
  { value: "happy", label: "Bright" },
  { value: "neutral", label: "Steady" },
  { value: "anxious", label: "Anxious" },
  { value: "sad", label: "Low" },
  { value: "motivated", label: "Motivated" },
];

export default function MicroCheckin() {
  const [energy, setEnergy] = useState(0);
  const [sleep, setSleep] = useState(0);
  const [mood, setMood] = useState("");
  const [insight, setInsight] = useState(null);

  const ready = energy > 0 && sleep > 0 && mood;

  const handleSubmit = () => {
    if (!ready) return;
    const result = generateInsight({
      energy,
      sleep_quality: sleep,
      mood,
      symptoms: [],
    });
    setInsight(result);
  };

  const reset = () => {
    setEnergy(0);
    setSleep(0);
    setMood("");
    setInsight(null);
  };

  if (insight) {
    return (
      <div className="rounded-3xl bg-card border border-border p-8 sm:p-10">
        <div className="flex items-center gap-3 mb-5">
          <div className="w-10 h-10 rounded-full bg-accent/20 flex items-center justify-center">
            <Sparkles className="w-5 h-5 text-primary" strokeWidth={1.5} />
          </div>
          <div>
            <div className="eyebrow">Your micro-insight</div>
            <h3 className="font-heading text-xl text-primary">Here's what we noticed</h3>
          </div>
        </div>
        <p className="text-muted-foreground leading-relaxed mb-6">{insight}</p>
        <div className="flex flex-wrap gap-3">
          <Link
            to="/register"
            className="inline-flex items-center gap-2 rounded-full px-6 py-3 bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            Start tracking daily <ArrowRight className="w-4 h-4" />
          </Link>
          <button
            onClick={reset}
            className="inline-flex items-center gap-2 rounded-full px-6 py-3 border border-border text-primary text-sm font-medium hover:border-primary/40 transition-colors"
          >
            Try again
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-3xl bg-card border border-border p-8 sm:p-10">
      <div className="text-center mb-8">
        <div className="eyebrow mb-2">30-second check-in</div>
        <h3 className="font-heading text-2xl text-primary mb-2">How are you feeling right now?</h3>
        <p className="text-sm text-muted-foreground">No account needed. Get an instant wellness insight.</p>
      </div>

      {/* Energy */}
      <div className="mb-6">
        <div className="flex items-center gap-2 mb-3">
          <Zap className="w-4 h-4 text-primary" strokeWidth={1.5} />
          <label className="text-sm font-medium text-primary">Energy level</label>
        </div>
        <div className="flex gap-2">
          {[1, 2, 3, 4, 5].map((n) => (
            <button
              key={n}
              onClick={() => setEnergy(n)}
              className={`flex-1 py-3 rounded-xl border text-sm font-medium transition-all ${
                energy === n
                  ? "bg-primary text-primary-foreground border-primary"
                  : "bg-background border-border text-muted-foreground hover:border-primary/30"
              }`}
            >
              {n}
            </button>
          ))}
        </div>
        <div className="flex justify-between mt-1.5 text-xs text-muted-foreground">
          <span>Exhausted</span>
          <span>Vibrant</span>
        </div>
      </div>

      {/* Sleep */}
      <div className="mb-6">
        <div className="flex items-center gap-2 mb-3">
          <Moon className="w-4 h-4 text-primary" strokeWidth={1.5} />
          <label className="text-sm font-medium text-primary">Sleep quality last night</label>
        </div>
        <div className="flex gap-2">
          {[1, 2, 3, 4, 5].map((n) => (
            <button
              key={n}
              onClick={() => setSleep(n)}
              className={`flex-1 py-3 rounded-xl border text-sm font-medium transition-all ${
                sleep === n
                  ? "bg-primary text-primary-foreground border-primary"
                  : "bg-background border-border text-muted-foreground hover:border-primary/30"
              }`}
            >
              {n}
            </button>
          ))}
        </div>
        <div className="flex justify-between mt-1.5 text-xs text-muted-foreground">
          <span>Poor</span>
          <span>Great</span>
        </div>
      </div>

      {/* Mood */}
      <div className="mb-8">
        <div className="flex items-center gap-2 mb-3">
          <Smile className="w-4 h-4 text-primary" strokeWidth={1.5} />
          <label className="text-sm font-medium text-primary">Mood</label>
        </div>
        <div className="flex flex-wrap gap-2">
          {MOODS.map((m) => (
            <button
              key={m.value}
              onClick={() => setMood(m.value)}
              className={`px-4 py-2.5 rounded-full border text-sm font-medium transition-all ${
                mood === m.value
                  ? "bg-primary text-primary-foreground border-primary"
                  : "bg-background border-border text-muted-foreground hover:border-primary/30"
              }`}
            >
              {m.label}
            </button>
          ))}
        </div>
      </div>

      <button
        onClick={handleSubmit}
        disabled={!ready}
        className="w-full inline-flex items-center justify-center gap-2 rounded-full px-8 py-3.5 bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
      >
        Get my insight <ArrowRight className="w-4 h-4" />
      </button>
    </div>
  );
}