import React from "react";
import { Heart } from "lucide-react";
import { CATEGORY_LABELS, DIFFICULTY_LABELS } from "@/data/healthCategories";

export default function HealthResourceCard({ resource, onClick, isFavorited, onToggleFavorite }) {
  return (
    <div className="health-card" onClick={onClick} role="button" tabIndex={0}
      onKeyDown={(e) => { if (e.key === "Enter") onClick(); }}>
      {onToggleFavorite && (
        <button
          className="health-card-fav"
          onClick={(e) => { e.stopPropagation(); onToggleFavorite(resource); }}
          aria-label={isFavorited ? "Remove from favorites" : "Add to favorites"}
          title={isFavorited ? "Remove from favorites" : "Save to favorites"}
        >
          <Heart
            size={18}
            fill={isFavorited ? "var(--clay)" : "none"}
            color={isFavorited ? "var(--clay)" : "var(--soft)"}
            strokeWidth={1.5}
          />
        </button>
      )}
      <span className="health-card-badge">{CATEGORY_LABELS[resource.category]}</span>
      <h3>{resource.title}</h3>
      <p>{resource.description}</p>
      <div className="health-card-meta">
        {resource.duration_minutes && <span>⏱ {resource.duration_minutes} min</span>}
        {resource.difficulty && <span>● {DIFFICULTY_LABELS[resource.difficulty] || resource.difficulty}</span>}
        {resource.subcategory && <span>{resource.subcategory.replace(/-/g, " ")}</span>}
      </div>
      {resource.tags?.length > 0 && (
        <div className="health-tags">
          {resource.tags.slice(0, 4).map((t) => (
            <span key={t} className="health-tag">{t.replace(/-/g, " ")}</span>
          ))}
        </div>
      )}
    </div>
  );
}