import React, { useEffect } from "react";
import ReactMarkdown from "react-markdown";
import { Heart } from "lucide-react";
import { CATEGORY_LABELS, DIFFICULTY_LABELS } from "@/data/healthCategories";

export default function HealthResourceModal({ resource, onClose, isFavorited, onToggleFavorite }) {
  useEffect(() => {
    const onKey = (e) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = "";
    };
  }, [onClose]);

  if (!resource) return null;

  return (
    <div className="health-modal-overlay" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="health-modal">
        <button className="health-modal-close" onClick={onClose} aria-label="Close">×</button>
        {onToggleFavorite && (
          <button
            className="health-modal-fav"
            onClick={() => onToggleFavorite(resource)}
            aria-label={isFavorited ? "Remove from favorites" : "Add to favorites"}
            title={isFavorited ? "Remove from favorites" : "Save to favorites"}
          >
            <Heart
              size={20}
              fill={isFavorited ? "var(--clay)" : "none"}
              color={isFavorited ? "var(--clay)" : "var(--soft)"}
              strokeWidth={1.5}
            />
            <span>{isFavorited ? "Favorited" : "Save to favorites"}</span>
          </button>
        )}
        <span className="health-card-badge">{CATEGORY_LABELS[resource.category]}</span>
        <h2>{resource.title}</h2>
        <p style={{ color: "var(--soft)", fontSize: 16, lineHeight: 1.6, marginBottom: 16 }}>{resource.description}</p>
        <div className="health-card-meta" style={{ marginBottom: 24 }}>
          {resource.duration_minutes && <span>⏱ {resource.duration_minutes} min</span>}
          {resource.difficulty && <span>● {DIFFICULTY_LABELS[resource.difficulty] || resource.difficulty}</span>}
          {resource.subcategory && <span>{resource.subcategory.replace(/-/g, " ")}</span>}
        </div>
        {resource.tags?.length > 0 && (
          <div className="health-tags" style={{ marginBottom: 24 }}>
            {resource.tags.map((t) => (
              <span key={t} className="health-tag">{t.replace(/-/g, " ")}</span>
            ))}
          </div>
        )}
        <div className="prose" style={{ maxWidth: "none" }}>
          <ReactMarkdown>{resource.content}</ReactMarkdown>
        </div>
        {resource.citations && (
          <div className="health-citations">
            <h4>Sources & References</h4>
            <div style={{ fontSize: 13, lineHeight: 1.7, color: "var(--soft)" }}>
              <ReactMarkdown>{resource.citations}</ReactMarkdown>
            </div>
          </div>
        )}
        <div className="health-disclaimer">
          <strong style={{ color: "var(--clay)" }}>Medical disclaimer:</strong> This information is for educational purposes only and is not a substitute for professional medical advice. Always consult your healthcare provider before trying any new recipe, exercise, supplement, or wellness routine — especially if you have a chronic condition, are pregnant, or take medication.
        </div>
      </div>
    </div>
  );
}