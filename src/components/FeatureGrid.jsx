import React from "react";
import { Link } from "react-router-dom";
import { useAuth } from "@/lib/AuthContext";
import { FEATURES } from "@/data/features";

export default function FeatureGrid() {
  const { user } = useAuth();

  return (
    <section className="section" style={{ paddingTop: 0 }}>
      <div className="wrap">
        <div className="section-head">
          <div>
            <div className="eyebrow">Everything VIDA LAB offers</div>
            <h2>Tools for your health journey</h2>
          </div>
          <p>From daily check-ins to long-term trends, appointment prep to AI guidance — each tool is designed to help you understand and advocate for your health.</p>
        </div>
        <div className="feature-grid">
          {FEATURES.map((f) => {
            const linkPath = f.memberOnly && !user ? "/app" : f.path;
            return (
              <Link key={f.title} to={linkPath} className="feature-card">
                <div className="feature-icon">
                  <f.icon size={22} strokeWidth={1.5} />
                </div>
                {f.plus && <span className="feature-badge">Vida+</span>}
                <h3>{f.title}</h3>
                <p>{f.description}</p>
                <span className="feature-link">{f.cta} →</span>
              </Link>
            );
          })}
        </div>
      </div>
    </section>
  );
}