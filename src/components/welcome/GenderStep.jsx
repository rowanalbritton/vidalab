import React, { useState } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import { Loader2, Heart, User, UserCircle } from "lucide-react";

export default function GenderStep({ onComplete }) {
  const { checkUserAuth } = useAuth();
  const [gender, setGender] = useState("");
  const [saving, setSaving] = useState(false);

  const handleSelect = async (value) => {
    setGender(value);
    setSaving(true);
    try {
      await base44.auth.updateMe({ gender: value });
      await checkUserAuth();
    } catch (e) {
      console.error("Failed to save gender", e);
    }
    setSaving(false);
    onComplete();
  };

  return (
    <div className="max-w-lg mx-auto">
      <div className="text-center mb-8">
        <div className="eyebrow mb-2">Step 1 · A bit about you</div>
        <h2 className="font-heading text-3xl text-primary">Which best describes you?</h2>
        <p className="text-muted-foreground mt-2">
          This helps us personalize your tracking. Female accounts include cycle phase tracking; male accounts skip it.
        </p>
      </div>

      <div className="grid gap-3">
        <button
          onClick={() => handleSelect("female")}
          disabled={saving}
          className={`flex items-center gap-4 rounded-2xl border p-5 text-left transition-all hover:border-primary/40 ${
            gender === "female" ? "border-primary bg-accent/10" : "border-border bg-card"
          }`}
        >
          <div className="w-12 h-12 rounded-full bg-vida-blush/40 flex items-center justify-center shrink-0">
            <Heart className="w-5 h-5 text-primary" strokeWidth={1.5} />
          </div>
          <div className="flex-1">
            <p className="text-sm font-medium text-primary">Female</p>
            <p className="text-xs text-muted-foreground mt-1">Includes cycle phase tracking and related insights</p>
          </div>
        </button>

        <button
          onClick={() => handleSelect("male")}
          disabled={saving}
          className={`flex items-center gap-4 rounded-2xl border p-5 text-left transition-all hover:border-primary/40 ${
            gender === "male" ? "border-primary bg-accent/10" : "border-border bg-card"
          }`}
        >
          <div className="w-12 h-12 rounded-full bg-accent/20 flex items-center justify-center shrink-0">
            <User className="w-5 h-5 text-primary" strokeWidth={1.5} />
          </div>
          <div className="flex-1">
            <p className="text-sm font-medium text-primary">Male</p>
            <p className="text-xs text-muted-foreground mt-1">Cycle phase tracking is hidden</p>
          </div>
        </button>

        <button
          onClick={() => handleSelect("prefer_not_to_say")}
          disabled={saving}
          className={`flex items-center gap-4 rounded-2xl border p-5 text-left transition-all hover:border-primary/40 ${
            gender === "prefer_not_to_say" ? "border-primary bg-accent/10" : "border-border bg-card"
          }`}
        >
          <div className="w-12 h-12 rounded-full bg-muted flex items-center justify-center shrink-0">
            <UserCircle className="w-5 h-5 text-primary" strokeWidth={1.5} />
          </div>
          <div className="flex-1">
            <p className="text-sm font-medium text-primary">Prefer not to say</p>
            <p className="text-xs text-muted-foreground mt-1">Cycle phase tracking stays hidden by default</p>
          </div>
        </button>
      </div>

      {saving && (
        <div className="flex items-center justify-center gap-2 mt-4 text-sm text-muted-foreground">
          <Loader2 className="w-4 h-4 animate-spin" /> Saving…
        </div>
      )}
    </div>
  );
}