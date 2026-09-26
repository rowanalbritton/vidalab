import React from "react";
import { useParams, Link, Navigate } from "react-router-dom";
import { getCondition } from "@/data/conditions";
import FavoriteButton from "@/components/FavoriteButton";

export default function ConditionDetail() {
  const { slug } = useParams();
  const condition = getCondition(slug);

  if (!condition) return <Navigate to="/research" replace />;

  return (
    <main>
      <header className="page-hero wrap">
        <div className="eyebrow">{condition.eyebrow}</div>
        <h1>{condition.title}</h1>
        <p>{condition.intro}</p>
        <div className="actions" style={{ position: "relative" }}>
          <FavoriteButton
            variant="inline"
            size={20}
            resource={{
              resource_id: `condition:${slug}`,
              resource_title: condition.title,
              resource_category: condition.eyebrow,
              resource_type: "condition",
              resource_url: `/conditions/${slug}`,
              resource_subtitle: condition.intro,
            }}
          />
          <span className={`stage${condition.stage.cls ? " " + condition.stage.cls : ""}`}>{condition.stage.text}</span>
          {condition.meta.map((m) => (
            <span key={m} className="topic">{m}</span>
          ))}
        </div>
      </header>

      <section style={{ background: "var(--paper)", borderTop: "1px solid var(--line)", borderBottom: "1px solid var(--line)" }}>
        <div className="wrap prose-grid">
          <aside>
            <div className="eyebrow">Key takeaways</div>
            {condition.takeaways.map((t, i) => (
              <p key={i}>{t}</p>
            ))}
          </aside>
          <article className="prose">
            {condition.sections.map((s, i) => (
              <React.Fragment key={i}>
                <h2>{s.h}</h2>
                <p>{s.p}</p>
              </React.Fragment>
            ))}
            <h2>Sources</h2>
            <ul>
              {condition.sources.map((src, i) => (
                <li key={i}><a href={src.url} target="_blank" rel="noopener noreferrer">{src.text}</a></li>
              ))}
            </ul>
            <h2>What This Means</h2>
            <p>{condition.whatThisMeans}</p>
            <h2>What We Still Don't Know</h2>
            <p>{condition.whatWeDontKnow}</p>
            <div className="actions">
              <Link className="button" to="/app">Follow {condition.eyebrow.split(" · ")[0]} in the VIDA LAB App →</Link>
            </div>
          </article>
        </div>
      </section>
    </main>
  );
}