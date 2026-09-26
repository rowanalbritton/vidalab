import React, { useState } from "react";
import { Link } from "react-router-dom";

const FILTERS = ["Everything", "Conditions", "Treatments", "Technology", "Body systems"];

const ITEMS = [
  {
    category: "conditions",
    to: "/conditions/migraine",
    stage: "approved",
    stageLabel: "ESTABLISHED + EVOLVING",
    title: "CGRP and migraine",
    meta: "Neurology · Treatment science",
  },
  {
    category: "conditions",
    to: "/conditions/pots",
    stage: "trial",
    stageLabel: "ACTIVE RESEARCH",
    title: "Autoimmunity in POTS",
    meta: "Autonomic nervous system · Immunology",
  },
  {
    category: "technology",
    to: "/research",
    stage: "",
    stageLabel: "EMERGING TECHNOLOGY",
    title: "Digital biomarkers",
    meta: "Diagnostics · Digital health",
  },
  {
    category: "technology",
    to: "/research",
    stage: "early",
    stageLabel: "EARLY RESEARCH",
    title: "Gene therapy delivery",
    meta: "Biomedical engineering · Cell biology",
  },
];

export default function ResearchExplorer() {
  const [active, setActive] = useState("Everything");

  const visible =
    active === "Everything"
      ? ITEMS
      : ITEMS.filter((i) => i.category === active.toLowerCase().replace(" ", "_"));

  return (
    <section className="section explorer">
      <div className="wrap">
        <div className="section-head">
          <div>
            <div className="eyebrow" style={{ color: "#a3b3a3" }}>Find your thread</div>
            <h2>Research Explorer</h2>
          </div>
          <p>Browse by the question you have—not the vocabulary you are expected to know.</p>
        </div>
        <div className="filters" role="group" aria-label="Filter research">
          {FILTERS.map((label) => (
            <button
              key={label}
              className={`filter ${active === label ? "active" : ""}`}
              onClick={() => setActive(label)}
              aria-pressed={active === label}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="explorer-list">
          {visible.map((item, i) => (
            <Link key={i} className="explorer-item" to={item.to}>
              <div>
                <span className={`stage ${item.stage}`}>{item.stageLabel}</span>
                <h3>{item.title}</h3>
                <p>{item.meta}</p>
              </div>
              <span>→</span>
            </Link>
          ))}
          {visible.length === 0 && (
            <p style={{ color: "#c8d4ca", padding: "12px 0" }}>
              No threads here yet — try another filter.
            </p>
          )}
        </div>
        <div className="actions">
          <Link
            className="button"
            style={{ background: "var(--cream)", color: "var(--forest)" }}
            to="/research"
          >
            Open Research Explorer
          </Link>
        </div>
      </div>
    </section>
  );
}