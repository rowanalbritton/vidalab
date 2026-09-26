import React from "react";
import { Link } from "react-router-dom";
import { useAuth } from "@/lib/AuthContext";
import UpgradeButton from "@/components/UpgradeButton";
import { LineChart, History, FileText, Sparkles, Check, CloudSun, Compass, FlaskConical, Stethoscope, MapPin } from "lucide-react";

const PLUS_BENEFITS = [
  {
    icon: CloudSun,
    title: "Body Weather",
    description: "Your week ahead, forecasted from your patterns — predicted energy, mood, and flare risk before they hit, with proactive actions to try.",
  },
  {
    icon: Compass,
    title: "The Vida Differential",
    description: "Stuck or dismissed? Your patterns mapped to conditions worth exploring, the tests that rule each in or out, and which specialists to see.",
  },
  {
    icon: FlaskConical,
    title: "Vida Experiments",
    description: "Stop guessing if that supplement or diet works. Run structured n=1 self-experiments and see — with confidence — what actually moves the needle.",
  },
  {
    icon: Stethoscope,
    title: "Appointment Concierge",
    description: "Walk in prepared. Predicted questions, a prioritized symptom narrative, tests to request, and an advocacy script so you're heard — not dismissed.",
  },
  {
    icon: MapPin,
    title: "Local Doctor Finder",
    description: "Find specialists and doctors in your area who match your needs — no more guessing where to turn next.",
  },
  {
    icon: LineChart,
    title: "Pattern Map",
    description: "See how energy, mood, and symptoms correlate across your cycle and over time — without guessing.",
  },
  {
    icon: History,
    title: "Unlimited History",
    description: "Free members see their latest 30 entries. Vida+ unlocks your full tracking history with no cap.",
  },
  {
    icon: FileText,
    title: "Save Reports as PDF",
    description: "Download condition reports and monthly health snapshots to bring to appointments or share with your care team.",
  },
];

const FREE_BENEFITS = [
  "Daily check-ins with instant insights",
  "30-day check-in history",
  "Ask Vida AI companion",
  "Full condition library access",
];

export default function VidaPlusSection() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";

  return (
    <section className="section" style={{ paddingTop: 0 }}>
      <div className="wrap">
        <div className="section-head">
          <div>
            <div className="eyebrow">Vida+ Membership</div>
            <h2>Go deeper into your patterns</h2>
          </div>
          <p>Free tracking covers the essentials. Vida+ unlocks the tools that turn daily check-ins into real clarity.</p>
        </div>

        <div className="vida-plus-grid">
          {/* Free tier card */}
          <div className="vida-tier-card">
            <div className="vida-tier-header">
              <span className="vida-tier-label">Free</span>
              <span className="vida-tier-price">$0<span>/forever</span></span>
            </div>
            <p className="vida-tier-tagline">Start tracking today, no payment needed.</p>
            <ul className="vida-tier-list">
              {FREE_BENEFITS.map((b) => (
                <li key={b}>
                  <Check size={16} strokeWidth={2} className="vida-check" />
                  <span>{b}</span>
                </li>
              ))}
            </ul>
            <Link
              to={user ? "/daily-signals" : "/register"}
              className="vida-tier-cta secondary"
            >
              {user ? "Start tracking" : "Create free account"}
            </Link>
          </div>

          {/* Vida+ tier card */}
          <div className="vida-tier-card plus">
            <div className="vida-plus-badge">Vida+</div>
            <div className="vida-tier-header">
              <span className="vida-tier-label">Vida+</span>
              <span className="vida-tier-price">$9.99<span>/month</span></span>
            </div>
            <p className="vida-tier-tagline">Everything in Free, plus the tools that turn daily tracking into real answers.</p>
            <ul className="vida-tier-list">
              {PLUS_BENEFITS.map((b) => (
                <li key={b.title}>
                  <span className="vida-benefit-icon">
                    <b.icon size={15} strokeWidth={1.5} />
                  </span>
                  <div>
                    <strong>{b.title}</strong>
                    <span>{b.description}</span>
                  </div>
                </li>
              ))}
            </ul>
            {isVidaPlus ? (
              <Link to="/pattern-map" className="vida-tier-cta plus active">
                <Sparkles size={15} strokeWidth={1.5} /> You're a Vida+ member
              </Link>
            ) : (
              <UpgradeButton className="vida-tier-cta plus" />
            )}
          </div>
        </div>
      </div>
    </section>
  );
}