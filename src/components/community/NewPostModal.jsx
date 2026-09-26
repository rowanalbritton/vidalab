import React, { useState } from "react";
import { Button } from "@/components/ui/button";
import { Loader2, X } from "lucide-react";
import { base44 } from "@/api/base44Client";
import { COMMUNITY_CATEGORIES } from "@/data/communityCategories";

export default function NewPostModal({ onClose, onCreated }) {
  const [form, setForm] = useState({
    display_name: "Anonymous",
    title: "",
    category: "general",
    content: "",
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const handleSubmit = async (e) => {
    e.preventDefault();
    const title = form.title.trim();
    const content = form.content.trim();
    if (title.length < 3) { setError("Title must be at least 3 characters."); return; }
    if (content.length < 1) { setError("Please write some content before posting."); return; }
    setSaving(true);
    setError(null);
    try {
      const created = await base44.entities.CommunityPost.create({
        display_name: form.display_name.trim() || "Anonymous",
        title,
        category: form.category,
        content,
        status: "active",
        flagged: false,
      });
      onCreated(created);
    } catch (e) {
      setError(e.message || "Failed to post. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/70 z-50 flex items-start justify-center p-5 sm:p-10 overflow-y-auto" onClick={onClose}>
      <div className="bg-card rounded-3xl max-w-2xl w-full p-6 sm:p-8 relative my-auto" onClick={(e) => e.stopPropagation()}>
        <button onClick={onClose} className="absolute top-4 right-4 text-muted-foreground hover:text-primary transition-colors w-10 h-10 flex items-center justify-center rounded-full hover:bg-muted">
          <X className="w-5 h-5" />
        </button>
        <h2 className="font-heading text-2xl text-primary mb-1">Start a discussion</h2>
        <p className="text-sm text-muted-foreground mb-6">Share an experience, ask a question, or offer a wellness tip. Your display name keeps you anonymous.</p>
        <form onSubmit={handleSubmit} className="space-y-5">
          <div>
            <label className="block text-sm font-medium text-primary mb-2">Display name</label>
            <input
              type="text"
              value={form.display_name}
              onChange={(e) => set("display_name", e.target.value)}
              maxLength={50}
              placeholder="Anonymous"
              className="w-full px-4 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent"
            />
            <p className="text-xs text-muted-foreground mt-1">This is how others see you. It doesn't link to your account.</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-primary mb-2">Title</label>
            <input
              type="text"
              value={form.title}
              onChange={(e) => set("title", e.target.value)}
              maxLength={200}
              placeholder="What's on your mind?"
              className="w-full px-4 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-primary mb-2">Category</label>
            <select
              value={form.category}
              onChange={(e) => set("category", e.target.value)}
              className="w-full px-4 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent"
            >
              {COMMUNITY_CATEGORIES.map((c) => (
                <option key={c.value} value={c.value}>{c.label}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-primary mb-2">Your post</label>
            <textarea
              value={form.content}
              onChange={(e) => set("content", e.target.value)}
              rows={6}
              maxLength={5000}
              placeholder="Share your experience, a tip, or a question…"
              className="w-full px-4 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent resize-none"
            />
          </div>
          {error && <p className="text-sm text-destructive">{error}</p>}
          <div className="flex gap-3 justify-end">
            <button type="button" onClick={onClose} className="px-6 py-2.5 rounded-full border border-border text-primary text-sm font-medium hover:bg-muted transition-colors">
              Cancel
            </button>
            <Button type="submit" disabled={saving} className="rounded-full px-6">
              {saving ? <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> Posting…</> : "Post to community"}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}