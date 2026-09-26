import React from "react";
import { Link } from "react-router-dom";
import NewsletterForm from "@/components/NewsletterForm";
import SubstackArticles from "@/components/SubstackArticles";
import ResearchExplorer from "@/components/ResearchExplorer";
import ScrollReveal, { StaggerGroup, StaggerItem } from "@/components/home/ScrollReveal";
import AppShowcase from "@/components/home/AppShowcase";
import AppStoreButton from "@/components/AppStoreButton";
import { BookOpen, HeartPulse, FlaskConical, Sparkles } from "lucide-react";

const FREE_RESOURCES = [
  {
    icon: BookOpen,
    title: "Condition Library",
    desc: "150+ chronic conditions explained with advocacy guides and action plans, all grounded in peer-reviewed research.",
    to: "/library",
  },
  {
    icon: HeartPulse,
    title: "The Vida Apothecary",
    desc: "Original recipes, gentle exercises, guided meditations, and wellness rituals — cited and evidence-informed.",
    to: "/health",
  },
  {
    icon: FlaskConical,
    title: "Research Archive",
    desc: "Emerging health research, biomedical technology, and diagnostics — translated into language that actually makes sense.",
    to: "/research",
  },
];

export default function Home() {
  return (
    <main>
      {/* Hero */}
      <section className="hero wrap">
        <div className="hero-copy">
          <div className="eyebrow">Research, translated</div>
          <h1>Understand what's changing in medicine.</h1>
          <p>VIDA LAB translates emerging health research, biomedical technology, diagnostics, and experimental treatments into clear explanations you can actually understand—then connects that learning to a private app designed to help you notice patterns in your own health story.</p>
          <div className="actions">
            <Link className="button" to="/research">Explore the Research <span>→</span></Link>
            <AppStoreButton className="button secondary">Get the App</AppStoreButton>
          </div>
        </div>
        <div className="hero-visual" aria-hidden="true">
          <div className="orbit"><div className="orbit-inner"></div></div>
          <div className="specimen one">
            <span className="stage trial">CLINICAL TRIALS</span>
            <div className="line"></div>
            <div className="line short"></div>
            <small>From hypothesis to human study</small>
          </div>
          <div className="specimen two">
            <span className="stage">EMERGING TECHNOLOGY</span>
            <div className="line"></div>
            <div className="line short"></div>
            <small>A clearer view of what comes next</small>
          </div>
        </div>
      </section>

      {/* Research — What's Changing in Medicine */}
      <ScrollReveal>
        <section className="section" id="changing">
          <div className="wrap">
            <div className="section-head">
              <div>
                <div className="eyebrow">The research horizon</div>
                <h2>What's Changing in Medicine</h2>
              </div>
              <p>New ideas are not all at the same stage. We separate established care, clinical trials, early research, and emerging technology so you can see where the evidence actually stands.</p>
            </div>
            <div className="research-grid">
              <Link className="research-card feature" to="/conditions/migraine">
                <div className="card-art"></div>
                <span className="stage approved">ESTABLISHED + EVOLVING</span>
                <h3>The new era of migraine prevention</h3>
                <p>How treatments targeting CGRP changed what prevention can look like—and what researchers are studying next.</p>
                <span className="card-link">Read the explainer →</span>
              </Link>
              <Link className="research-card" to="/conditions/pots">
                <span className="stage trial">ACTIVE RESEARCH</span>
                <h3>Rethinking POTS</h3>
                <p>Researchers are testing how immune, vascular, and nervous-system mechanisms may overlap without turning early findings into certainty.</p>
                <span className="card-link">Explore POTS research →</span>
              </Link>
              <Link className="research-card" to="/conditions/long-covid">
                <span className="stage early">EVOLVING EVIDENCE</span>
                <h3>Long COVID's biological clues</h3>
                <p>What scientists are learning about persistence, immunity, metabolism, rehabilitation, and treatment trials.</p>
                <span className="card-link">See what we know →</span>
              </Link>
              <Link className="research-card" to="/research#technology">
                <span className="stage">EMERGING TECHNOLOGY</span>
                <h3>Diagnostics beyond a snapshot</h3>
                <p>Wearables, digital biomarkers, and continuous measurements could change how fluctuating illness is studied.</p>
                <span className="card-link">Explore diagnostics →</span>
              </Link>
              <Link className="research-card" to="/conditions/fibromyalgia">
                <span className="stage early">EVOLVING EVIDENCE</span>
                <h3>Fibromyalgia research</h3>
                <p>New work is examining pain processing and neurobiology alongside possible immune mechanisms.</p>
                <span className="card-link">Understand the evidence →</span>
              </Link>
            </div>
            <div className="actions">
              <Link className="button secondary" to="/research">Browse all research</Link>
            </div>
          </div>
        </section>
      </ScrollReveal>

      <ScrollReveal>
        <ResearchExplorer />
      </ScrollReveal>

      {/* Free Resources */}
      <ScrollReveal>
        <section className="section" id="free-resources" style={{ paddingTop: "60px" }}>
          <div className="wrap">
            <div className="section-head">
              <div>
                <div className="eyebrow">Free to explore</div>
                <h2>Resources, open to everyone</h2>
              </div>
              <p>No account needed. Browse the condition library, wellness apothecary, and research archive at your own pace.</p>
            </div>
            <StaggerGroup className="free-resource-grid">
              {FREE_RESOURCES.map((r) => (
                <StaggerItem key={r.title}>
                  <Link to={r.to} className="feature-card">
                    <div className="feature-icon">
                      <r.icon size={22} strokeWidth={1.5} />
                    </div>
                    <h3>{r.title}</h3>
                    <p>{r.desc}</p>
                    <span className="feature-link">Explore →</span>
                  </Link>
                </StaggerItem>
              ))}
            </StaggerGroup>
          </div>
        </section>
      </ScrollReveal>

      {/* App Presentation */}
      <ScrollReveal>
        <section className="section" id="app-showcase-section">
          <div className="wrap">
            <div className="app-showcase-head">
              <div className="eyebrow">The VIDA LAB App</div>
              <h2>A calmer way to keep track of your health story.</h2>
              <p>Log symptoms, energy, sleep, and notes; look for correlations; run simple personal experiments; prepare for medical appointments; and keep useful research close at hand. Designed for reflection and organization — not diagnosis.</p>
              <StaggerGroup className="topic-cloud" stagger={0.05}>
                <StaggerItem><span className="topic">Today</span></StaggerItem>
                <StaggerItem><span className="topic">Patterns</span></StaggerItem>
                <StaggerItem><span className="topic">Ask</span></StaggerItem>
                <StaggerItem><span className="topic">Experiments</span></StaggerItem>
                <StaggerItem><span className="topic">Doctor Prep</span></StaggerItem>
                <StaggerItem><span className="topic">Library</span></StaggerItem>
                <StaggerItem><span className="topic">Weekly Reports</span></StaggerItem>
                <StaggerItem><span className="topic">VIDA+</span></StaggerItem>
              </StaggerGroup>
            </div>
            <AppShowcase />
            <div className="actions" style={{ justifyContent: "center", marginTop: "40px" }}>
              <AppStoreButton>Download on the App Store →</AppStoreButton>
            </div>
          </div>
        </section>
      </ScrollReveal>

      {/* Compact Vida+ pitch */}
      <ScrollReveal>
        <section className="section" id="vida-plus-compact" style={{ paddingTop: "40px", paddingBottom: "80px" }}>
          <div className="wrap">
            <div className="vida-compact-pitch">
              <div>
                <div className="eyebrow">Vida+ Membership</div>
                <h2>Go deeper into your patterns</h2>
                <p>Free tracking covers the essentials. Vida+ unlocks pattern mapping, body weather forecasts, appointment prep, and unlimited history — for $9.99/month.</p>
              </div>
              <Link className="button" to="/vida-plus">
                <Sparkles size={16} strokeWidth={1.5} /> Learn about Vida+
              </Link>
            </div>
          </div>
        </section>
      </ScrollReveal>

      {/* Substack */}
      <ScrollReveal>
        <SubstackArticles />
      </ScrollReveal>

      {/* Newsletter */}
      <ScrollReveal>
        <section className="section">
          <div className="wrap newsletter" id="newsletter">
            <div>
              <div className="eyebrow">The VIDA LAB newsletter</div>
              <h2>Stay curious.</h2>
              <p>Get thoughtful updates on health research, biomedical technology, chronic illness, and the ideas changing medicine.</p>
            </div>
            <NewsletterForm />
          </div>
        </section>
      </ScrollReveal>
    </main>
  );
}