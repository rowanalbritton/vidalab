import React, { useState, useEffect } from "react";
import { base44 } from "@/api/base44Client";
import Loader from "@/components/Loader";
import FavoriteButton from "@/components/FavoriteButton";

export default function SubstackArticles() {
  const [articles, setArticles] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    base44.entities.SubstackArticle.list("-sort_order", 6)
      .then(setArticles)
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  if (loading) return (
    <section className="section">
      <div className="wrap text-center">
        <Loader />
      </div>
    </section>
  );
  if (!articles.length) return null;

  return (
    <section className="section" style={{ background: "var(--paper)", borderTop: "1px solid var(--line)", borderBottom: "1px solid var(--line)" }}>
      <div className="wrap">
        <div className="section-head">
          <div>
            <div className="eyebrow">From the Substack</div>
            <h2>Latest writing</h2>
          </div>
          <p>New essays and research reflections, published on Substack. Click any card to read the full piece.</p>
        </div>
        <div className="substack-grid">
          {articles.map((a, i) => (
            <a key={i} className="research-card" href={a.link} target="_blank" rel="noopener noreferrer" style={{ position: "relative" }}>
              <FavoriteButton
                resource={{
                  resource_id: a.id || a.link,
                  resource_title: a.title,
                  resource_category: "substack",
                  resource_type: "substack",
                  resource_url: a.link,
                  resource_subtitle: a.description,
                }}
              />
              <span className="stage">SUBSTACK</span>
              <h3>{a.title}</h3>
              <p>{a.description || "Click to read the full essay on Substack."}</p>
              <span className="card-link">Read on Substack →</span>
            </a>
          ))}
        </div>
        <div className="actions" style={{ marginTop: 30 }}>
          <a className="button" href="https://vidalab.substack.com" target="_blank" rel="noopener noreferrer">Subscribe on Substack →</a>
        </div>
      </div>
    </section>
  );
}