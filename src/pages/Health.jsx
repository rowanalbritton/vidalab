import React, { useState, useEffect, useSyncExternalStore } from "react";
import { base44 } from "@/api/base44Client";
import { useAuth } from "@/lib/AuthContext";
import { subscribe, getFavorites, toggleFavorite as storeToggle, loadFavorites } from "@/lib/favoritesStore";
import { CATEGORIES, SUBCATEGORIES, FOCUS_GROUPS } from "@/data/healthCategories";
import HealthResourceCard from "@/components/health/HealthResourceCard";
import HealthResourceModal from "@/components/health/HealthResourceModal";
import Loader from "@/components/Loader";
import GoogleSyncButton from "@/components/GoogleSyncButton";
import { Heart, SlidersHorizontal, X, ListTodo } from "lucide-react";

export default function Health() {
  const { isAuthenticated } = useAuth();
  const [resources, setResources] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeCategory, setActiveCategory] = useState("all");
  const [activeSub, setActiveSub] = useState("all");
  const [activeFocus, setActiveFocus] = useState([]);
  const [search, setSearch] = useState("");
  const [selected, setSelected] = useState(null);
  const favorites = useSyncExternalStore(subscribe, getFavorites, getFavorites);
  const favMap = {};
  favorites.forEach((f) => { favMap[f.resource_id] = f; });
  const [showFavoritesOnly, setShowFavoritesOnly] = useState(false);
  const [showFilters, setShowFilters] = useState(false);

  useEffect(() => {
    base44.entities.HealthResource.list("sort_order", 1000)
      .then(setResources)
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (isAuthenticated) loadFavorites();
  }, [isAuthenticated]);

  const handleCategoryChange = (catId) => {
    setActiveCategory(catId);
    setActiveSub("all");
    const applicableTags = new Set(
      FOCUS_GROUPS
        .filter((g) => catId === "all" || !g.categories || g.categories.includes(catId))
        .flatMap((g) => g.filters
          .filter((f) => catId === "all" || !f.categories || f.categories.includes(catId))
          .map((f) => f.tag)
        )
    );
    setActiveFocus((prev) => prev.filter((tag) => applicableTags.has(tag)));
  };

  const subs = activeCategory !== "all" ? SUBCATEGORIES[activeCategory] || [] : [];

  const visibleFocusGroups = FOCUS_GROUPS.filter((g) =>
    activeCategory === "all" || !g.categories || g.categories.includes(activeCategory)
  );

  const toggleFocus = (tag) => setActiveFocus((prev) => prev.includes(tag) ? prev.filter((t) => t !== tag) : [...prev, tag]);

  const toggleFavorite = (resource) => {
    if (!isAuthenticated) return;
    storeToggle({
      resource_id: resource.id,
      resource_title: resource.title,
      resource_category: resource.category,
      resource_type: "health",
      resource_url: "/health",
      resource_subtitle: resource.description,
    });
  };

  const activeFilterCount =
    (activeSub !== "all" ? 1 : 0) +
    activeFocus.length +
    (showFavoritesOnly ? 1 : 0);

  const clearAll = () => {
    setActiveSub("all");
    setActiveFocus([]);
    setShowFavoritesOnly(false);
  };

  const filtered = resources.filter((r) => {
    const fav = !showFavoritesOnly || favMap[r.id];
    const cat = activeCategory === "all" || r.category === activeCategory;
    const sub = activeSub === "all" || r.subcategory === activeSub;
    const focus = activeFocus.length === 0 || activeFocus.every((tag) => r.tags?.includes(tag));
    const q = !search ||
      r.title.toLowerCase().includes(search.toLowerCase()) ||
      r.description?.toLowerCase().includes(search.toLowerCase()) ||
      r.tags?.some((t) => t.toLowerCase().includes(search.toLowerCase()));
    return fav && cat && sub && focus && q;
  });

  return (
    <>
      <section className="page-hero wrap">
        <div className="eyebrow">The Vida Apothecary</div>
        <h1>Recipes, Remedies &amp; Rituals</h1>
        <p>A curated collection of original recipes, gentle exercises, guided meditations, evidence-informed supplement guides, and daily wellness rituals to support your journey with chronic illness — all cited, all free.</p>
      </section>

      <div className="wrap" style={{ marginBottom: 32 }}>
        <div className="callout" style={{ borderColor: "var(--clay)", background: "#fdf6f3" }}>
          <p style={{ fontSize: 14, color: "var(--soft)", margin: 0 }}>
            <strong style={{ color: "var(--clay)" }}>Medical disclaimer:</strong> This library is for educational purposes only and is not a substitute for professional medical advice, diagnosis, or treatment. Always consult your healthcare provider before starting any new diet, exercise, supplement, or wellness routine — especially if you have a chronic condition or take medication.
          </p>
        </div>
      </div>

      <div className="wrap" style={{ marginBottom: 24, display: "flex", gap: 12, flexWrap: "wrap", alignItems: "center" }}>
        <span style={{ fontSize: 14, color: "var(--soft)" }}>Sync your favorited practices to Google Tasks:</span>
        <GoogleSyncButton
          connectorId="6ab2084927827baadedd137e"
          functionName="sync-practices-to-tasks"
          label="Sync to Google Tasks"
          connectLabel="Connect Google Tasks"
          successLabel="Tasks created"
          icon={ListTodo}
        />
      </div>

      <section className="section" style={{ paddingTop: 0, paddingBottom: 100 }}>
        <div className="wrap">
          <div className="health-filters">
            {CATEGORIES.map((c) => (
              <button
                key={c.id}
                className={`filter${activeCategory === c.id ? " active" : ""}`}
                onClick={() => handleCategoryChange(c.id)}
              >
                {c.label}
              </button>
            ))}
          </div>

          <div className="health-filter-bar">
            <input
              className="health-search"
              type="search"
              placeholder="Search recipes, exercises, supplements…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{ margin: 0, flex: 1, maxWidth: "none" }}
            />
            <button
              className={`health-filter-btn${showFilters ? " active" : ""}`}
              onClick={() => setShowFilters((v) => !v)}
            >
              <SlidersHorizontal size={16} strokeWidth={1.5} />
              Filters
              {activeFilterCount > 0 && <span className="health-filter-count">{activeFilterCount}</span>}
            </button>
          </div>

          {showFilters && (
            <div className="health-filter-dropdown">
              {subs.length > 0 && (
                <div className="health-filter-group">
                  <span className="health-focus-label">Subcategory</span>
                  <div className="health-filters" style={{ marginBottom: 0 }}>
                    <button
                      className={`filter${activeSub === "all" ? " active" : ""}`}
                      onClick={() => setActiveSub("all")}
                    >
                      All {CATEGORIES.find((c) => c.id === activeCategory)?.label.toLowerCase()}
                    </button>
                    {subs.map((s) => (
                      <button
                        key={s}
                        className={`filter${activeSub === s ? " active" : ""}`}
                        onClick={() => setActiveSub(s)}
                      >
                        {s.replace(/-/g, " ")}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {visibleFocusGroups.map((group) => {
                const visibleFilters = group.filters.filter(
                  (f) => activeCategory === "all" || !f.categories || f.categories.includes(activeCategory)
                );
                if (visibleFilters.length === 0) return null;
                return (
                  <div key={group.label} className="health-filter-group">
                    <span className="health-focus-label">{group.label}</span>
                    <div className="health-filters" style={{ marginBottom: 0 }}>
                      {visibleFilters.map((f) => (
                        <button
                          key={f.tag}
                          className={`filter${activeFocus.includes(f.tag) ? " active" : ""}`}
                          onClick={() => toggleFocus(f.tag)}
                        >
                          {f.label}
                        </button>
                      ))}
                    </div>
                  </div>
                );
              })}

              {isAuthenticated && (
                <div className="health-filter-group">
                  <span className="health-focus-label">Saved</span>
                  <div className="health-filters" style={{ marginBottom: 0 }}>
                    <button
                      className={`filter${showFavoritesOnly ? " active" : ""}`}
                      onClick={() => setShowFavoritesOnly((v) => !v)}
                      style={{ display: "flex", alignItems: "center", gap: 6 }}
                    >
                      <Heart size={14} fill={showFavoritesOnly ? "currentColor" : "none"} />
                      My Favorites ({favorites.length})
                    </button>
                  </div>
                </div>
              )}

              {activeFilterCount > 0 && (
                <button className="health-filter-clear" onClick={clearAll}>
                  <X size={14} strokeWidth={1.5} /> Clear all filters
                </button>
              )}
            </div>
          )}

          <p style={{ color: "var(--taupe)", fontSize: 14, marginBottom: 20 }}>
            {filtered.length} {filtered.length === 1 ? "resource" : "resources"}
          </p>

          {loading ? (
            <Loader label="Loading wellness library…" className="py-20" />
          ) : filtered.length === 0 ? (
            <p style={{ color: "var(--soft)", padding: 40, textAlign: "center" }}>No resources match your search. Try a different filter or keyword.</p>
          ) : (
            <div className="health-grid">
              {filtered.map((r) => (
                <HealthResourceCard
                  key={r.id}
                  resource={r}
                  onClick={() => setSelected(r)}
                  isFavorited={!!favMap[r.id]}
                  onToggleFavorite={isAuthenticated ? toggleFavorite : undefined}
                />
              ))}
            </div>
          )}
        </div>
      </section>

      <HealthResourceModal
        resource={selected}
        onClose={() => setSelected(null)}
        isFavorited={selected ? !!favMap[selected.id] : false}
        onToggleFavorite={isAuthenticated ? toggleFavorite : undefined}
      />
    </>
  );
}