import React from "react";
import { Check } from "lucide-react";

export default function StepIndicator({ current, total }) {
  return (
    <div className="flex items-center justify-center gap-2 mb-10">
      {Array.from({ length: total }, (_, i) => i + 1).map((step) => (
        <div key={step} className="flex items-center gap-2">
          <div
            className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium transition-all ${
              step < current
                ? "bg-primary text-primary-foreground"
                : step === current
                ? "bg-primary text-primary-foreground ring-4 ring-primary/15"
                : "bg-muted text-muted-foreground border border-border"
            }`}
          >
            {step < current ? <Check className="w-4 h-4" /> : step}
          </div>
          {step < total && (
            <div className={`w-8 sm:w-16 h-px ${step < current ? "bg-primary" : "bg-border"}`} />
          )}
        </div>
      ))}
    </div>
  );
}