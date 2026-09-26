import { base44 } from "@/api/base44Client";

let favorites = [];
let loaded = false;
let loading = false;
const listeners = new Set();

function emit() {
  listeners.forEach((l) => l(favorites));
}

export function getFavorites() {
  return favorites;
}

export async function loadFavorites() {
  if (loaded || loading) return;
  loading = true;
  try {
    favorites = await base44.entities.Favorite.list("-created_date", 500);
    loaded = true;
  } catch (e) {
    favorites = [];
  } finally {
    loading = false;
    emit();
  }
}

export function resetFavorites() {
  favorites = [];
  loaded = false;
  loading = false;
  emit();
}

export async function toggleFavorite(resource) {
  const existing = favorites.find((f) => f.resource_id === resource.resource_id);
  if (existing) {
    try {
      await base44.entities.Favorite.delete(existing.id);
      favorites = favorites.filter((f) => f.id !== existing.id);
    } catch (e) {
      console.error("Failed to remove favorite", e);
    }
  } else {
    try {
      const fav = await base44.entities.Favorite.create({
        resource_id: resource.resource_id,
        resource_title: resource.resource_title,
        resource_category: resource.resource_category || "",
        resource_type: resource.resource_type,
        resource_url: resource.resource_url || "",
        resource_subtitle: resource.resource_subtitle || "",
        resource_image: resource.resource_image || "",
      });
      favorites = [fav, ...favorites];
    } catch (e) {
      console.error("Failed to save favorite", e);
    }
  }
  emit();
}

export async function removeFavorite(resourceId) {
  const existing = favorites.find((f) => f.resource_id === resourceId);
  if (!existing) return;
  try {
    await base44.entities.Favorite.delete(existing.id);
    favorites = favorites.filter((f) => f.id !== existing.id);
    emit();
  } catch (e) {
    console.error("Failed to remove favorite", e);
  }
}

export function subscribe(cb) {
  listeners.add(cb);
  return () => {
    listeners.delete(cb);
  };
}