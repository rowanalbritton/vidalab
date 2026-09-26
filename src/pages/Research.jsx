import React, { useState } from "react";
import { Link } from "react-router-dom";
import FavoriteButton from "@/components/FavoriteButton";

const ITEMS = [
  { tags: ["condition", "treatment", "body"], stage: "approved", stageText: "FDA APPROVED", title: "CGRP and migraine prevention", sub: "Migraine · Neurology · 7 min", to: "/conditions/migraine", id: "conditions" },
  { tags: ["condition", "body", "topic"], stage: "trial", stageText: "CLINICAL TRIALS", title: "Is POTS partly autoimmune?", sub: "POTS · Autonomic nervous system · 6 min", to: "/conditions/pots" },
  { tags: ["condition", "body", "topic"], stage: "early", stageText: "EARLY RESEARCH", title: "Long COVID's biological clues", sub: "Long COVID · Immunology · 8 min", to: "/conditions/long-covid" },
  { tags: ["condition", "body", "topic"], stage: "early", stageText: "EARLY RESEARCH", title: "Fibromyalgia beyond central sensitization", sub: "Fibromyalgia · Pain science · 7 min", to: "/conditions/fibromyalgia" },
  { tags: ["technology", "body"], stage: "", stageText: "EMERGING TECHNOLOGY", title: "Continuous digital biomarkers", sub: "Digital health · Diagnostics · 5 min", to: "/research", anchor: "technology" },
  { tags: ["treatment", "technology"], stage: "early", stageText: "EARLY RESEARCH", title: "Delivering gene therapies safely", sub: "Gene therapy · Biomedical engineering · 9 min", to: "/research", anchor: "treatments" },
];

const FILTERS = [
  { label: "Everything", value: "all" },
  { label: "Condition", value: "condition" },
  { label: "Treatment", value: "treatment" },
  { label: "Technology", value: "technology" },
  { label: "Body system", value: "body" },
  { label: "Article topic", value: "topic" },
];

export default function Research() {
  const [active, setActive] = useState("all");

  const visible = ITEMS.filter((item) => active === "all" || item.tags.includes(active));

  return (
    <main>
      <header className="page-hero wrap">
        <div className="eyebrow">VIDA LAB Research Explorer</div>
        <h1>Start with what you want to understand.</h1>
        <p>Search the edges of medicine by condition, treatment, technology, research stage, body system, or topic. Every explainer tells you what we know—and what we do not.</p>
      </header>

      <section className="section explorer" style={{ paddingTop: "70px" }}>
        <div className="wrap">
          <div className="filters" role="group">
            {FILTERS.map((f) => (
              <button
                key={f.value}
                className={`filter${active === f.value ? " active" : ""}`}
                onClick={() => setActive(f.value)}
              >
                {f.label}
              </button>
            ))}
          </div>
          <div className="explorer-list">
            {visible.map((item, i) => (
              <Link
                key={i}
                className="explorer-item"
                to={item.anchor ? `${item.to}#${item.anchor}` : item.to}
                id={item.anchor || item.id}
                style={{ position: "relative" }}
              >
                <FavoriteButton
                  resource={{
                    resource_id: `research:${item.to}${item.anchor ? `#${item.anchor}` : ""}`,
                    resource_title: item.title,
                    resource_category: item.tags.join(", "),
                    resource_type: "condition",
                    resource_url: item.anchor ? `${item.to}#${item.anchor}` : item.to,
                    resource_subtitle: item.sub,
                  }}
                />
                <div>
                  <span className={`stage${item.stage ? " " + item.stage : ""}`}>{item.stageText}</span>
                  <h3>{item.title}</h3>
                  <p>{item.sub}</p>
                </div>
                <span>→</span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section className="section">
        <div className="wrap">
          <div className="section-head">
            <div>
              <div className="eyebrow">The VIDA LAB format</div>
              <h2>A consistent way through complicated science.</h2>
            </div>
            <p>Every research explainer answers the same practical questions so you can compare an early laboratory finding with medicine available today.</p>
          </div>
          <div className="standards">
            <div className="standard"><span className="eyebrow">01</span><h3>What is it?</h3><p>The idea, condition, treatment, or technology in plain language.</p></div>
            <div className="standard"><span className="eyebrow">02</span><h3>Why does it matter?</h3><p>The problem researchers are trying to solve.</p></div>
            <div className="standard"><span className="eyebrow">03</span><h3>Where is the science now?</h3><p>Laboratory work, human trials, regulatory review, or clinical use.</p></div>
            <div className="standard"><span className="eyebrow">04</span><h3>What are the limits?</h3><p>Uncertainty, study design, access, and the questions still open.</p></div>
          </div>
        </div>
      </section>
    </main>
  );
}