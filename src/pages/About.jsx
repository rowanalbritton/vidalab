import React from "react";
import SubstackArticles from "@/components/SubstackArticles";
import NewsletterForm from "@/components/NewsletterForm";
import WhyVidaLab from "@/components/WhyVidaLab";
import FounderBio from "@/components/FounderBio";

export default function About() {
  return (
    <main>
      <header className="page-hero wrap">
        <div className="eyebrow">About VIDA LAB</div>
        <h1>Science should not require a second language.</h1>
        <p>VIDA LAB translates emerging health research, biomedical technology, diagnostics, and experimental treatments into clear explanations you can actually understand. I read the studies, then explain what they found, how far along the science is, and what is still uncertain — so you don't have to wade through a research database or settle for a wellness post with no science behind it.</p>
      </header>

      <FounderBio />

      <WhyVidaLab />

      <section className="section">
        <div className="wrap">
          <div className="section-head">
            <div>
              <div className="eyebrow">Editorial standards</div>
              <h2>Trust is part of the product.</h2>
            </div>
            <p>I update my work as evidence changes. These principles guide every article and update.</p>
          </div>
          <div className="standards">
            <div className="standard"><h3>Start at the source</h3><p>We link to peer-reviewed research and authoritative health institutions whenever possible.</p></div>
            <div className="standard"><h3>Label the stage</h3><p>Established care, approval, clinical trials, and early research are not interchangeable.</p></div>
            <div className="standard"><h3>Show uncertainty</h3><p>We identify limitations, disagreements, unanswered questions, and gaps in who was studied.</p></div>
            <div className="standard"><h3>Review as science moves</h3><p>Articles show when they were updated, and meaningful changes are incorporated over time.</p></div>
            <div className="standard"><h3>Never medical advice</h3><p>VIDA LAB provides education. Decisions about care belong with a qualified healthcare professional.</p></div>
            <div className="standard"><h3>Respect your intelligence</h3><p>Accessible does not mean simplistic. We explain technical ideas without talking down to readers.</p></div>
          </div>
        </div>
      </section>

      <SubstackArticles />

      <section className="section" style={{ background: "var(--paper)", borderTop: "1px solid var(--line)" }}>
        <div className="wrap">
          <div className="section-head">
            <div>
              <div className="eyebrow">The VIDA LAB newsletter</div>
              <h2>Stay curious.</h2>
            </div>
            <p>Get thoughtful updates on health research, the latest science I'm reading, and the ideas changing how we understand our bodies.</p>
          </div>
          <NewsletterForm />
        </div>
      </section>
    </main>
  );
}