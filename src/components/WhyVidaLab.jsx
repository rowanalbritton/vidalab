import React from "react";
import { Link } from "react-router-dom";
import { useAuth } from "@/lib/AuthContext";
import { FEATURES } from "@/data/features";

export default function WhyVidaLab() {
  const { user } = useAuth();

  return (
    <section className="section">
      <div className="wrap">
        <div className="section-head">
          <div>
            <div className="eyebrow">Why Vida Lab</div>
            <h2>The tools I wished I'd had.</h2>
          </div>
          <p>Most health platforms stop at information. I wanted to build something that turns research into tools you can actually use — tracking, pattern-finding, experiment-running, and appointment-prepping, all in one place.</p>
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