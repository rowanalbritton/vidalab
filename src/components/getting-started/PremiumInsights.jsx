import React from "react";
import { Link } from "react-router-dom";
import { useAuth } from "@/lib/AuthContext";
import UpgradeButton from "@/components/UpgradeButton";
import { LineChart, ClipboardList, TrendingUp, Lock } from "lucide-react";

const INSIGHTS = [
  {
    icon: TrendingUp,
    title: "Trends",
    description: "Visualize energy, sleep, and mood over 90 days to spot long-term shifts.",
    path: "/trends",
    plus: false,
  },
  {
    icon: LineChart,
    title: "Pattern Map",
    description: "See how energy shifts across cycle phases and which symptoms cluster together.",
    path: "/pattern-map",
    plus: true,
  },
  {
    icon: ClipboardList,
    title: "Doctor Prep",
    description: "Turn recent check-ins into a printable health snapshot for your next appointment.",
    path: "/doctor-prep",
    plus: true,
  },
];

export default function PremiumInsights() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus" || user?.role === "admin";

  return (
    <div>
      <div className="text-center mb-10">
        <div className="eyebrow mb-2">Where insights live</div>
        <h2 className="font-heading text-3xl text-primary">Your data turns into clarity</h2>
        <p className="text-muted-foreground mt-2 max-w-lg mx-auto">
          As your check-ins accumulate, these tools turn raw entries into visual patterns and printable summaries.
        </p>
      </div>

      <div className="grid gap-3 mb-8">
        {INSIGHTS.map((insight) => {
          const locked = insight.plus && !isVidaPlus;
          return (
            <div key={insight.title} className="flex items-start gap-4 rounded-2xl bg-card border border-border p-5">
              <div className="w-10 h-10 rounded-xl bg-accent/20 flex items-center justify-center shrink-0">
                <insight.icon className="w-5 h-5 text-primary" strokeWidth={1.5} />
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="text-sm font-medium text-primary">{insight.title}</h3>
                  {insight.plus && (
                    <span className="text-[10px] uppercase tracking-wider font-semibold text-primary bg-accent/20 px-2 py-0.5 rounded-full">
                      Vida+
                    </span>
                  )}
                </div>
                <p className="text-sm text-muted-foreground leading-relaxed">{insight.description}</p>
              </div>
              {locked ? (
                <Lock className="w-4 h-4 text-muted-foreground shrink-0 mt-1" />
              ) : (
                <Link to={insight.path} className="text-xs text-primary font-medium shrink-0 mt-1 hover:underline">
                  Open →
                </Link>
              )}
            </div>
          );
        })}
      </div>

      {!isVidaPlus && (
        <div className="rounded-2xl bg-primary/5 border border-primary/20 p-6 text-center">
          <p className="text-sm text-muted-foreground mb-4">
            Pattern Map and Doctor Prep unlock with Vida+. Trends is free for everyone.
          </p>
          <UpgradeButton className="inline-flex items-center gap-2 rounded-full px-8 py-3.5 bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors">
            Get Vida+ →
          </UpgradeButton>
        </div>
      )}
    </div>
  );
}