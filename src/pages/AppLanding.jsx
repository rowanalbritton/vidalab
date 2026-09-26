import React from "react";
import { Link } from "react-router-dom";
import { useAuth } from "@/lib/AuthContext";
import UpgradeButton from "@/components/UpgradeButton";

export default function AppLanding() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus" || user?.role === "admin";

  return (
    <main>
      <section className="hero wrap">
        <div className="hero-copy">
          <div className="eyebrow">The VIDA LAB App</div>
          <h1>Your personalized window into emerging medicine.</h1>
          <p>Follow the health topics you care about, discover relevant research, save clear explanations, and see where an idea sits between laboratory discovery and real-world medicine.</p>
          <div className="actions">
            <Link className="button" to={user ? "/daily-signals" : "/register"}>
              {user ? "Open Daily Signals →" : "Start tracking free →"}
            </Link>
            <Link className="button secondary" to="/research">Explore research now</Link>
            {user && !isVidaPlus && (
              <UpgradeButton className="button secondary">Get Vida+ →</UpgradeButton>
            )}
          </div>
          <p style={{ fontSize: "13px" }}>{isVidaPlus ? "You're a Vida+ member — all features unlocked." : "Start with a free account. Vida+ unlocks pattern mapping, doctor prep, and unlimited history."}</p>
        </div>
        <div className="phone">
          <div className="phone-top">
            <strong style={{ fontFamily: "var(--serif)" }}>VIDA LAB</strong>
            <span className="eyebrow" style={{ color: "#86c09a" }}>FOR YOU</span>
          </div>
          <h3 style={{ color: "#e4ede2", fontSize: "31px" }}>What are you curious about?</h3>
          <div className="topic-cloud">
            <span className="topic">Migraine</span>
            <span className="topic">POTS</span>
            <span className="topic">Pain science</span>
            <span className="topic">Diagnostics</span>
          </div>
          <div className="phone-card">
            <span className="stage trial">CLINICAL TRIALS</span>
            <h4>A study in an area you follow</h4>
            <p>See what researchers tested, what they found, and what happens next.</p>
          </div>
        </div>
      </section>

      <section className="section" style={{ background: "var(--paper)" }}>
        <div className="wrap">
          <div className="section-head">
            <div>
              <div className="eyebrow">Built around your questions</div>
              <h2>Research is easier to follow when it has a thread.</h2>
            </div>
            <p>VIDA LAB connects conditions, technologies, and treatments without pretending every connection is proven.</p>
          </div>
          <div className="app-grid">
            <div className="app-feature"><span className="number">01</span><h3>Follow health topics</h3><p>Choose conditions and research areas—from migraine and POTS to biomedical engineering.</p></div>
            <div className="app-feature"><span className="number">02</span><h3>Discover emerging research</h3><p>Find developments relevant to you, labeled by how mature the science is.</p></div>
            <div className="app-feature"><span className="number">03</span><h3>Save your library</h3><p>Keep articles and explainers together so you can return when you have energy.</p></div>
            <div className="app-feature"><span className="number">04</span><h3>Receive research updates</h3><p>Track areas of medicine you care about as evidence and availability change.</p></div>
            <div className="app-feature"><span className="number">05</span><h3>Understand the path</h3><p>See the distance between a laboratory result, clinical trial, approval, and patient access.</p></div>
            <div className="app-feature"><span className="number">06</span><h3>Keep it personal</h3><p>Personalization shapes discovery. It does not turn educational content into medical advice.</p></div>
          </div>
        </div>
      </section>

      <section className="section">
        <div className="wrap">
          <div className="section-head">
            <div>
              <div className="eyebrow">Start tracking</div>
              <h2>Three tools that turn check-ins into clarity.</h2>
            </div>
            <p>The private side of VIDA LAB, designed for reflection—not diagnosis.</p>
          </div>
          <div className="app-grid">
            <Link className="app-feature" to={user ? "/daily-signals" : "/register"} style={{ display: "block" }}>
              <span className="number">01</span>
              <h3>Daily Signals</h3>
              <p>Log energy, sleep, mood, cycle, and symptoms in two minutes. Each check-in returns a contextual educational insight.</p>
            </Link>
            <Link className="app-feature" to={user ? "/pattern-map" : "/register"} style={{ display: "block" }}>
              <span className="number">02</span>
              <h3>Pattern Map <span className="stage" style={{ marginLeft: 8 }}>VIDA+</span></h3>
              <p>See how energy shifts across cycle phases, which symptoms cluster, and what your mood landscape looks like.</p>
            </Link>
            <Link className="app-feature" to={user ? "/doctor-prep" : "/register"} style={{ display: "block" }}>
              <span className="number">03</span>
              <h3>Doctor Prep <span className="stage" style={{ marginLeft: 8 }}>VIDA+</span></h3>
              <p>Turn recent check-ins into a printable health snapshot with key metrics and suggested clinician questions.</p>
            </Link>
          </div>
          <div className="actions">
            <Link className="button" to={user ? "/daily-signals" : "/register"}>
              {user ? "Open the app →" : "Create your free account →"}
            </Link>
            {user && !isVidaPlus && (
              <UpgradeButton className="button">Get Vida+ →</UpgradeButton>
            )}
          </div>
        </div>
      </section>
    </main>
  );
}