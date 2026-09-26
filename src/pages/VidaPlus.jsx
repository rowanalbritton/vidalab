import React from "react";
import { Link } from "react-router-dom";
import ScrollReveal from "@/components/home/ScrollReveal";
import VidaPlusSection from "@/components/VidaPlusSection";
import AppStoreButton from "@/components/AppStoreButton";
import { Smartphone, Sparkles } from "lucide-react";

const HOW_IT_WORKS = [
  { step: "01", title: "Download the app", desc: "Available on the App Store. Create your free account in under a minute." },
  { step: "02", title: "Log daily check-ins", desc: "Two minutes a day — energy, sleep, mood, symptoms. The signals that make patterns real." },
  { step: "03", title: "Unlock Vida+", desc: "Subscribe for $9.99/month to access pattern mapping, forecasts, experiments, and appointment prep." },
];

export default function VidaPlus() {
  return (
    <main>
      <section className="page-hero wrap">
        <div className="eyebrow">Vida+ Membership</div>
        <h1>Go deeper into your patterns.</h1>
        <p>Free tracking covers the essentials. Vida+ unlocks the tools that turn daily check-ins into real clarity — pattern mapping, forecasts, appointment prep, and unlimited history. For $9.99/month.</p>
        <div className="actions">
          <AppStoreButton icon={<Smartphone size={16} strokeWidth={1.5} />}> Get the App</AppStoreButton>
          <Link className="button secondary" to="/register">Create free account</Link>
        </div>
      </section>

      <ScrollReveal>
        <VidaPlusSection />
      </ScrollReveal>

      <ScrollReveal>
        <section className="section" style={{ paddingTop: "40px" }}>
          <div className="wrap">
            <div className="section-head">
              <div>
                <div className="eyebrow">How it works</div>
                <h2>Three steps to clarity</h2>
              </div>
            </div>
            <div className="standards">
              {HOW_IT_WORKS.map((h) => (
                <div key={h.step} className="standard">
                  <div style={{ fontSize: "36px", fontFamily: "var(--serif)", color: "var(--sky-deep)", marginBottom: "12px", lineHeight: 1 }}>{h.step}</div>
                  <h3 style={{ fontFamily: "var(--sans)", fontSize: "18px", fontWeight: 500, marginBottom: "8px" }}>{h.title}</h3>
                  <p style={{ color: "var(--soft)", fontSize: "14px", lineHeight: 1.6, margin: 0 }}>{h.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </section>
      </ScrollReveal>

      <ScrollReveal>
        <section className="section" style={{ paddingTop: "40px", paddingBottom: "100px" }}>
          <div className="wrap">
            <div className="vida-compact-pitch">
              <div>
                <div className="eyebrow">Ready?</div>
                <h2>Your patterns are waiting.</h2>
                <p>Start free, upgrade when you're ready. $9.99/month, cancel anytime.</p>
              </div>
              <AppStoreButton icon={<Smartphone size={16} strokeWidth={1.5} />}> Download VIDA LAB</AppStoreButton>
            </div>
          </div>
        </section>
      </ScrollReveal>
    </main>
  );
}