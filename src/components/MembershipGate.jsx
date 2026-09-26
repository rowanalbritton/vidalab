import React from "react";
import { Link } from "react-router-dom";
import { Lock, Sparkles } from "lucide-react";
import UpgradeButton from "@/components/UpgradeButton";

export default function MembershipGate({ title, children }) {
  return (
    <div className="max-w-2xl mx-auto px-5 sm:px-8 py-16 text-center">
      <div className="w-14 h-14 rounded-full bg-vida-blush flex items-center justify-center mx-auto mb-6">
        <Lock className="w-6 h-6 text-primary" strokeWidth={1.5} />
      </div>
      <h2 className="font-heading text-3xl text-primary mb-3 text-balance">{title || "A Vida+ feature"}</h2>
      <p className="text-muted-foreground mb-8 max-w-md mx-auto leading-relaxed">
        {children || "Pattern Map and Doctor Prep are part of Vida+, which unlocks your full pattern history, correlation views, and printable health snapshots."}
      </p>
      <div className="flex flex-col sm:flex-row gap-3 justify-center">
        <Link to="/daily-signals" className="px-6 py-3 rounded-full border border-primary/30 text-primary text-sm font-medium hover:bg-primary/5 transition-colors">
          Start tracking free
        </Link>
        <UpgradeButton className="px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors inline-flex items-center gap-2" />
      </div>
    </div>
  );
}