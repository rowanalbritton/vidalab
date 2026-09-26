import { useEffect, useSyncExternalStore } from "react";
import { Heart } from "lucide-react";
import { useAuth } from "@/lib/AuthContext";
import { subscribe, getFavorites, toggleFavorite, loadFavorites, resetFavorites } from "@/lib/favoritesStore";

export default function FavoriteButton({ resource, variant = "card", size = 18 }) {
  const { isAuthenticated } = useAuth();
  const favorites = useSyncExternalStore(subscribe, getFavorites, getFavorites);
  const isFav = favorites.some((f) => f.resource_id === resource.resource_id);

  useEffect(() => {
    if (isAuthenticated) loadFavorites();
    else resetFavorites();
  }, [isAuthenticated]);

  if (!isAuthenticated) return null;

  const handle = (e) => {
    e.preventDefault();
    e.stopPropagation();
    toggleFavorite(resource);
  };

  return (
    <button
      type="button"
      className={`fav-btn fav-btn-${variant}${isFav ? " is-fav" : ""}`}
      onClick={handle}
      aria-label={isFav ? "Remove from favorites" : "Save to favorites"}
      title={isFav ? "Remove from favorites" : "Save to favorites"}
    >
      <Heart
        size={size}
        fill={isFav ? "var(--clay)" : "none"}
        color={isFav ? "var(--clay)" : "var(--soft)"}
        strokeWidth={1.5}
      />
    </button>
  );
}