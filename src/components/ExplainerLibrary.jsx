import React, { useState, useEffect } from "react";
import { base44 } from "@/api/base44Client";
import { Search, Clock, Lock, X, Sparkles } from "lucide-react";
import ReactMarkdown from "react-markdown";
import { useAuth } from "@/lib/AuthContext";
import UpgradeButton from "@/components/UpgradeButton";
import FavoriteButton from "@/components/FavoriteButton";

const CATEGORIES = [
  { value: "all", label: "All" },
  { value: "cycle", label: "Cycle" },
  { value: "sleep", label: "Sleep" },
  { value: "mood", label: "Mood" },
  { value: "nutrition", label: "Nutrition" },
  { value: "movement", label: "Movement" },
  { value: "stress", label: "Stress" },
  { value: "hormones", label: "Hormones" },
];

export default function ExplainerLibrary() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus" || user?.role === "admin";
  const [explainers, setExplainers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("all");
  const [selected, setSelected] = useState(null);

  useEffect(() => {
    (async () => {
      try {
        const data = await base44.entities.Explainer.list("-created_date", 200);
        setExplainers(data.filter((e) => e.is_public !== false));
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const filtered = explainers.filter((e) => {
    const matchesCat = category === "all" || e.category === category;
    const q = query.toLowerCase();
    const matchesQuery = !q ||
      (e.title || "").toLowerCase().includes(q) ||
      (e.subtitle || "").toLowerCase().includes(q) ||
      (e.content || "").toLowerCase().includes(q) ||
      (e.category || "").toLowerCase().includes(q);
    return matchesCat && matchesQuery;
  });

  return (
    <div>
      <div className="eyebrow" style={{ marginBottom: 10 }}>Wellness Explainers</div>
      <h2 style={{ fontSize: "clamp(28px,4vw,42px)", margin: "0 0 12px" }}>Learn the building blocks of feeling well.</h2>
      <p style={{ color: "var(--soft)", maxWidth: 600, margin: "0 0 28px" }}>
        Short, research-backed articles on sleep, mood, nutrition, movement, and more — so you can understand the why behind what you track.
      </p>

      {/* Search */}
      <div style={{ position: "relative", marginBottom: 20 }}>
        <Search size={18} style={{ position: "absolute", left: 18, top: "50%", transform: "translateY(-50%)", color: "var(--soft)" }} />
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search explainers..."
          style={{ width: "100%", border: "1px solid var(--line)", borderRadius: 100, padding: "15px 20px 15px 50px", background: "var(--paper)", color: "var(--ink)", outline: "none", fontSize: 16 }}
        />
      </div>

      {/* Category filters */}
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 36 }}>
        {CATEGORIES.map((c) => (
          <button
            key={c.value}
            onClick={() => setCategory(c.value)}
            style={{
              padding: "9px 16px",
              borderRadius: 100,
              border: `1px solid ${category === c.value ? "var(--forest)" : "var(--line)"}`,
              background: category === c.value ? "var(--forest)" : "transparent",
              color: category === c.value ? "var(--cream)" : "var(--soft)",
              cursor: "pointer",
              fontSize: 13,
              transition: "all .2s",
            }}
          >
            {c.label}
          </button>
        ))}
      </div>

      {/* Results */}
      {loading ? (
        <p style={{ color: "var(--soft)" }}>Loading explainers…</p>
      ) : filtered.length === 0 ? (
        <div style={{ textAlign: "center", padding: "40px 20px" }}>
          <p style={{ fontSize: 16, color: "var(--forest)", marginBottom: 6 }}>No explainers found{query ? ` for “{query}”` : ""}.</p>
          <p style={{ fontSize: 14, color: "var(--soft)" }}>Try a different search or category.</p>
        </div>
      ) : (
        <>
          <p style={{ color: "var(--soft)", fontSize: 14, marginBottom: 20 }}>{filtered.length} {filtered.length === 1 ? "article" : "articles"} found</p>
          <div className="substack-grid">
            {filtered.map((e) => {
              const locked = e.is_vida_plus && !isVidaPlus;
              return (
                <div
                  key={e.id}
                  onClick={() => setSelected(e)}
                  className="research-card"
                  style={{ minHeight: 200, cursor: "pointer", position: "relative" }}
                >
                  <FavoriteButton
                    resource={{
                      resource_id: e.id,
                      resource_title: e.title,
                      resource_category: e.category,
                      resource_type: "explainer",
                      resource_url: "/library",
                      resource_subtitle: e.subtitle,
                    }}
                  />
                  <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                    <span className="stage">{e.category}</span>
                    {e.is_vida_plus && (
                      <span className="stage trial" style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
                        {locked ? <Lock size={10} /> : <Sparkles size={10} />} Vida+
                      </span>
                    )}
                  </div>
                  <h3 style={{ marginTop: 14, fontSize: 22 }}>{e.title}</h3>
                  {e.subtitle && <p>{e.subtitle}</p>}
                  <div style={{ marginTop: "auto", display: "flex", alignItems: "center", gap: 6, fontSize: 13, color: "var(--moss)", fontWeight: 600 }}>
                    <Clock size={13} /> {e.read_time_minutes || 5} min read
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}

      {/* Article modal */}
      {selected && (
        <div
          onClick={() => setSelected(null)}
          style={{
            position: "fixed", inset: 0, zIndex: 50,
            display: "flex", alignItems: "center", justifyContent: "center",
            padding: 20, background: "rgba(18,23,19,.5)", backdropFilter: "blur(4px)",
          }}
        >
          <div
            onClick={(e) => e.stopPropagation()}
            style={{
              maxWidth: 680, width: "100%", maxHeight: "85vh", overflowY: "auto",
              background: "var(--paper)", borderRadius: 24, padding: "clamp(24px, 5vw, 40px) clamp(20px, 4vw, 36px)",
              border: "1px solid var(--line)", position: "relative",
            }}
          >
            <button
              onClick={() => setSelected(null)}
              style={{ position: "absolute", top: 20, right: 20, border: 0, background: "none", cursor: "pointer", color: "var(--soft)" }}
            >
              <X size={20} />
            </button>
            <span className="stage" style={{ textTransform: "capitalize" }}>{selected.category}</span>
            <h2 style={{ fontSize: "clamp(24px, 5vw, 32px)", margin: "14px 0 8px" }}>{selected.title}</h2>
            {selected.subtitle && <p style={{ color: "var(--soft)", fontSize: 17, marginBottom: 16 }}>{selected.subtitle}</p>}
            <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 13, color: "var(--soft)", marginBottom: 24 }}>
              <Clock size={13} /> {selected.read_time_minutes || 5} min read
            </div>
            {selected.is_vida_plus && !isVidaPlus ? (
              <div style={{ textAlign: "center", padding: "30px 20px", borderRadius: 16, background: "var(--cream)", border: "1px solid var(--line)" }}>
                <Lock size={28} style={{ color: "var(--forest)", marginBottom: 12 }} />
                <p style={{ color: "var(--forest)", fontSize: 17, marginBottom: 6 }}>This is a Vida+ article</p>
                <p style={{ color: "var(--soft)", fontSize: 14, marginBottom: 20, maxWidth: 380, margin: "0 auto 20px" }}>
                  Upgrade to Vida+ to unlock this article and all premium wellness explainers.
                </p>
                <UpgradeButton className="button" />
              </div>
            ) : (
              <div className="prose" style={{ fontSize: 15 }}>
                <ReactMarkdown>{selected.content}</ReactMarkdown>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}