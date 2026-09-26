import { useEffect, useSyncExternalStore } from "react";
import { Link } from "react-router-dom";
import { base44 } from "@/api/base44Client";
import { useAuth } from "@/lib/AuthContext";
import { subscribe, getFavorites, loadFavorites, removeFavorite } from "@/lib/favoritesStore";
import Loader from "@/components/Loader";
import { Heart, ExternalLink, BookOpen, FlaskConical, FileText, Newspaper, Sparkles, HeartPulse } from "lucide-react";

const TYPE_META = {
  health: { label: "Apothecary", icon: HeartPulse },
  disease: { label: "Condition Report", icon: BookOpen },
  explainer: { label: "Wellness Explainer", icon: Sparkles },
  substack: { label: "Substack Article", icon: Newspaper },
  research_paper: { label: "Research Paper", icon: FileText },
  condition: { label: "Research Explainer", icon: FlaskConical },
};

const TYPE_ORDER = ["disease", "condition", "explainer", "health", "substack", "research_paper"];

export default function Favorites() {
  const { isAuthenticated } = useAuth();
  const favorites = useSyncExternalStore(subscribe, getFavorites, getFavorites);

  useEffect(() => {
    if (isAuthenticated) loadFavorites();
  }, [isAuthenticated]);

  if (!isAuthenticated) {
    return (
      <main className="wrap" style={{ padding: "120px 0", textAlign: "center" }}>
        <h1 style={{ marginBottom: 16 }}>Your Favorites</h1>
        <p style={{ color: "var(--soft)", maxWidth: 460, margin: "0 auto 28px" }}>
          Sign in to save research papers, condition reports, wellness explainers, recipes, and articles — all in one place.
        </p>
        <Link className="button" to="/login">Sign in</Link>
      </main>
    );
  }

  if (!favorites || favorites.length === 0) {
    return (
      <main className="wrap" style={{ padding: "120px 0", textAlign: "center" }}>
        <div className="eyebrow" style={{ marginBottom: 14 }}>Saved</div>
        <h1 style={{ marginBottom: 16 }}>Your Favorites</h1>
        <p style={{ color: "var(--soft)", maxWidth: 480, margin: "0 auto 28px" }}>
          You haven't saved anything yet. Tap the heart on any resource across VIDA LAB to keep it here for easy access.
        </p>
        <div className="actions" style={{ justifyContent: "center" }}>
          <Link className="button" to="/library">Browse the Library</Link>
          <Link className="button secondary" to="/health">Explore the Apothecary</Link>
        </div>
      </main>
    );
  }

  const grouped = {};
  favorites.forEach((f) => {
    const t = f.resource_type || "health";
    (grouped[t] = grouped[t] || []).push(f);
  });
  const orderedTypes = TYPE_ORDER.filter((t) => grouped[t]);

  const handleRemove = (resourceId) => removeFavorite(resourceId);

  return (
    <main>
      <header className="page-hero wrap">
        <div className="eyebrow">Saved</div>
        <h1>Your Favorites</h1>
        <p style={{ fontSize: 20, color: "var(--soft)", maxWidth: 720 }}>
          Everything you've saved across VIDA LAB — condition reports, research, wellness explainers, recipes, and articles — gathered in one place.
        </p>
      </header>

      <section className="section" style={{ paddingTop: 20, paddingBottom: 100 }}>
        <div className="wrap">
          {orderedTypes.map((type) => {
            const meta = TYPE_META[type] || { label: type, icon: Heart };
            const Icon = meta.icon;
            const items = grouped[type];
            return (
              <div key={type} style={{ marginBottom: 56 }}>
                <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 22 }}>
                  <span className="feature-icon" style={{ width: 38, height: 38, marginBottom: 0 }}>
                    <Icon size={18} strokeWidth={1.5} />
                  </span>
                  <div>
                    <div className="eyebrow" style={{ marginBottom: 2 }}>{meta.label}</div>
                    <h2 style={{ fontSize: 24, margin: 0 }}>{items.length} saved</h2>
                  </div>
                </div>
                <div className="health-grid">
                  {items.map((f) => {
                    const url = f.resource_url;
                    const isExternal = url && url.startsWith("http");
                    const CardTag = isExternal ? "a" : Link;
                    const cardProps = isExternal
                      ? { href: url, target: "_blank", rel: "noopener noreferrer" }
                      : { to: url || "#" };
                    return (
                      <div key={f.id} className="health-card" style={{ cursor: "pointer" }}>
                        <button
                          className="health-card-fav"
                          onClick={(e) => { e.preventDefault(); e.stopPropagation(); handleRemove(f.resource_id); }}
                          aria-label="Remove from favorites"
                          title="Remove from favorites"
                        >
                          <Heart size={18} fill="var(--clay)" color="var(--clay)" strokeWidth={1.5} />
                        </button>
                        <CardTag {...cardProps} style={{ textDecoration: "none", color: "inherit", display: "flex", flexDirection: "column", height: "100%" }}>
                          <span className="health-card-badge">{meta.label}</span>
                          <h3 style={{ fontSize: 18, fontWeight: 500, margin: "0 0 8px" }}>{f.resource_title}</h3>
                          {f.resource_subtitle && <p style={{ color: "var(--soft)", fontSize: 14, lineHeight: 1.6, margin: "0 0 12px", flex: 1 }}>{f.resource_subtitle}</p>}
                          <div className="health-card-meta">
                            {isExternal ? <span style={{ display: "inline-flex", alignItems: "center", gap: 4 }}><ExternalLink size={12} /> Open</span> : <span>View →</span>}
                          </div>
                        </CardTag>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      </section>
    </main>
  );
}