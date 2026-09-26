import React, { useState, useEffect, useCallback } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import { Plus, MessageCircle, Shield } from "lucide-react";
import PostCard from "@/components/community/PostCard";
import NewPostModal from "@/components/community/NewPostModal";
import PostDetailModal from "@/components/community/PostDetailModal";
import Loader from "@/components/Loader";
import { COMMUNITY_CATEGORIES } from "@/data/communityCategories";

export default function Community() {
  const { user } = useAuth();
  const isAdmin = user?.role === "admin";
  const [posts, setPosts] = useState([]);
  const [replyCounts, setReplyCounts] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [category, setCategory] = useState("all");
  const [showFlaggedOnly, setShowFlaggedOnly] = useState(false);
  const [showNewPost, setShowNewPost] = useState(false);
  const [selectedPost, setSelectedPost] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [postsData, repliesData] = await Promise.all([
        base44.entities.CommunityPost.list("-created_date", 100),
        base44.entities.CommunityReply.list("-created_date", 500),
      ]);
      setPosts(postsData);
      const counts = {};
      repliesData.forEach((r) => {
        counts[r.post_id] = (counts[r.post_id] || 0) + 1;
      });
      setReplyCounts(counts);
    } catch (e) {
      setError("We couldn't load the community feed. Please try again.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const filteredPosts = posts.filter((p) => {
    if (category !== "all" && p.category !== category) return false;
    if (showFlaggedOnly && !p.flagged) return false;
    return true;
  });

  const handlePostCreated = (post) => {
    setPosts((prev) => [post, ...prev]);
    setReplyCounts((prev) => ({ ...prev, [post.id]: 0 }));
    setShowNewPost(false);
  };

  const handlePostUpdated = (id, data) => {
    setPosts((prev) => prev.map((p) => (p.id === id ? { ...p, ...data } : p)));
    if (selectedPost?.id === id) setSelectedPost((prev) => ({ ...prev, ...data }));
  };

  const handlePostDeleted = (id) => {
    setPosts((prev) => prev.filter((p) => p.id !== id));
    if (selectedPost?.id === id) setSelectedPost(null);
  };

  const handleReport = async (post) => {
    try {
      await base44.functions.invoke("flag-community-content", { type: "post", id: post.id });
      setPosts((prev) => prev.map((p) => (p.id === post.id ? { ...p, flagged: true } : p)));
    } catch (e) {
      console.error(e);
    }
  };

  const handleToggleStatus = async (post) => {
    const newStatus = post.status === "active" ? "hidden" : "active";
    try {
      await base44.entities.CommunityPost.update(post.id, { status: newStatus });
      handlePostUpdated(post.id, { status: newStatus });
    } catch (e) {
      console.error(e);
    }
  };

  const handleDelete = async (post) => {
    if (!confirm("Delete this post permanently? This cannot be undone.")) return;
    try {
      await base44.entities.CommunityPost.delete(post.id);
      handlePostDeleted(post.id);
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <main className="max-w-4xl mx-auto px-5 sm:px-8 py-10">
      <div className="mb-8">
        <span className="text-xs uppercase tracking-widest text-muted-foreground">Community</span>
        <h1 className="font-heading text-4xl text-primary mt-1">Community</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">
          A space to share experiences, ask questions, and exchange wellness tips — anonymously.
        </p>
      </div>

      <div className="rounded-2xl bg-vida-blush/30 border border-vida-blush px-5 py-4 mb-8 text-sm text-muted-foreground leading-relaxed">
        <strong className="text-primary">A reminder:</strong> This is a peer-to-peer space for sharing experiences and wellness tips — not medical advice. Always consult a qualified healthcare professional for personal health concerns. Be kind, respectful, and on-topic. Posts that violate our guidelines will be removed by moderators.
      </div>

      <div className="flex flex-wrap items-center gap-2 mb-6">
        <button
          onClick={() => setCategory("all")}
          className={`px-4 py-2 rounded-full text-sm transition-all ${
            category === "all" ? "bg-primary text-primary-foreground" : "bg-card border border-border text-muted-foreground hover:border-primary/40"
          }`}
        >
          All
        </button>
        {COMMUNITY_CATEGORIES.map((c) => (
          <button
            key={c.value}
            onClick={() => setCategory(c.value)}
            className={`px-4 py-2 rounded-full text-sm transition-all ${
              category === c.value ? "bg-primary text-primary-foreground" : "bg-card border border-border text-muted-foreground hover:border-primary/40"
            }`}
          >
            {c.label}
          </button>
        ))}
      </div>

      <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
        <p className="text-sm text-muted-foreground">
          {loading ? "Loading…" : `${filteredPosts.length} ${filteredPosts.length === 1 ? "post" : "posts"}`}
        </p>
        <div className="flex gap-2">
          {isAdmin && (
            <button
              onClick={() => setShowFlaggedOnly((v) => !v)}
              className={`px-4 py-2 rounded-full text-sm border transition-all flex items-center gap-2 ${
                showFlaggedOnly ? "bg-vida-clay/10 border-vida-clay text-vida-clay" : "bg-card border-border text-muted-foreground hover:border-primary/40"
              }`}
            >
              <Shield className="w-4 h-4" /> {showFlaggedOnly ? "Show all" : "Moderation queue"}
            </button>
          )}
          <button
            onClick={() => setShowNewPost(true)}
            className="px-5 py-2 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors flex items-center gap-2"
          >
            <Plus className="w-4 h-4" /> New Post
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-12"><Loader /></div>
      ) : error ? (
        <p className="text-sm text-destructive text-center py-12">{error}</p>
      ) : filteredPosts.length === 0 ? (
        <div className="text-center py-12 rounded-2xl border border-dashed border-border">
          <MessageCircle className="w-8 h-8 text-muted-foreground mx-auto mb-3" strokeWidth={1} />
          <p className="text-muted-foreground text-sm">
            {showFlaggedOnly ? "No reported posts to review." : "No posts in this category yet. Start the conversation."}
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredPosts.map((post) => (
            <PostCard
              key={post.id}
              post={post}
              replyCount={replyCounts[post.id] || 0}
              onOpen={setSelectedPost}
              onReport={handleReport}
              isAdmin={isAdmin}
              onToggleStatus={handleToggleStatus}
              onDelete={handleDelete}
            />
          ))}
        </div>
      )}

      {showNewPost && <NewPostModal onClose={() => setShowNewPost(false)} onCreated={handlePostCreated} />}
      {selectedPost && (
        <PostDetailModal
          post={selectedPost}
          onClose={() => setSelectedPost(null)}
          isAdmin={isAdmin}
          onPostUpdated={handlePostUpdated}
          onPostDeleted={handlePostDeleted}
        />
      )}
    </main>
  );
}