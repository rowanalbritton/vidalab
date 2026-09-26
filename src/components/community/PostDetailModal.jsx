import React, { useState, useEffect, useCallback } from "react";
import { base44 } from "@/api/base44Client";
import { X, Flag, EyeOff, Eye, Trash2 } from "lucide-react";
import { categoryLabel } from "@/data/communityCategories";
import ReplyForm from "./ReplyForm";
import Loader from "@/components/Loader";

function timeAgo(dateStr) {
  const date = new Date(dateStr);
  const diff = Date.now() - date.getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}d ago`;
  return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export default function PostDetailModal({ post, onClose, isAdmin, onPostUpdated, onPostDeleted }) {
  const [replies, setReplies] = useState([]);
  const [loadingReplies, setLoadingReplies] = useState(true);
  const [reporting, setReporting] = useState(false);
  const [reported, setReported] = useState(false);

  const loadReplies = useCallback(async () => {
    setLoadingReplies(true);
    try {
      const items = await base44.entities.CommunityReply.filter({ post_id: post.id }, "created_date", 200);
      setReplies(items);
    } catch (e) {
      console.error(e);
    } finally {
      setLoadingReplies(false);
    }
  }, [post.id]);

  useEffect(() => { loadReplies(); }, [loadReplies]);

  const handleReplyAdded = (reply) => setReplies((prev) => [...prev, reply]);
  const handleReplyUpdated = (id, data) => setReplies((prev) => prev.map((r) => (r.id === id ? { ...r, ...data } : r)));
  const handleReplyDeleted = (id) => setReplies((prev) => prev.filter((r) => r.id !== id));

  const handleReportPost = async () => {
    setReporting(true);
    try {
      await base44.functions.invoke("flag-community-content", { type: "post", id: post.id });
      setReported(true);
    } catch (e) {
      console.error(e);
    } finally {
      setReporting(false);
    }
  };

  const handleReportReply = async (replyId) => {
    try {
      await base44.functions.invoke("flag-community-content", { type: "reply", id: replyId });
      handleReplyUpdated(replyId, { flagged: true });
    } catch (e) {
      console.error(e);
    }
  };

  const handleTogglePostStatus = async () => {
    const newStatus = post.status === "active" ? "hidden" : "active";
    try {
      await base44.entities.CommunityPost.update(post.id, { status: newStatus });
      onPostUpdated(post.id, { status: newStatus });
    } catch (e) {
      console.error(e);
    }
  };

  const handleDeletePost = async () => {
    if (!confirm("Delete this post permanently? This cannot be undone.")) return;
    try {
      await base44.entities.CommunityPost.delete(post.id);
      onPostDeleted(post.id);
    } catch (e) {
      console.error(e);
    }
  };

  const handleToggleReplyStatus = async (reply) => {
    const newStatus = reply.status === "active" ? "hidden" : "active";
    try {
      await base44.entities.CommunityReply.update(reply.id, { status: newStatus });
      handleReplyUpdated(reply.id, { status: newStatus });
    } catch (e) {
      console.error(e);
    }
  };

  const handleDeleteReply = async (replyId) => {
    if (!confirm("Delete this reply permanently?")) return;
    try {
      await base44.entities.CommunityReply.delete(replyId);
      handleReplyDeleted(replyId);
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/70 z-50 flex items-start justify-center p-5 sm:p-10 overflow-y-auto" onClick={onClose}>
      <div className="bg-card rounded-3xl max-w-2xl w-full p-6 sm:p-8 relative my-auto" onClick={(e) => e.stopPropagation()}>
        <button onClick={onClose} className="absolute top-4 right-4 text-muted-foreground hover:text-primary transition-colors w-10 h-10 flex items-center justify-center rounded-full hover:bg-muted">
          <X className="w-5 h-5" />
        </button>

        {/* Post header */}
        <div className="mb-6">
          <div className="flex items-center gap-2 mb-3 flex-wrap">
            <span className="text-xs font-medium text-primary bg-vida-sage/20 px-2.5 py-1 rounded-full">
              {categoryLabel(post.category)}
            </span>
            {post.flagged && (
              <span className="text-xs text-vida-clay bg-vida-clay/10 px-2 py-0.5 rounded-full flex items-center gap-1">
                <Flag className="w-3 h-3" /> Reported
              </span>
            )}
            {post.status === "hidden" && (
              <span className="text-xs text-muted-foreground bg-muted px-2 py-0.5 rounded-full">Hidden</span>
            )}
          </div>
          <h2 className="font-heading text-2xl text-primary mb-3">{post.title}</h2>
          <p className="text-sm text-foreground whitespace-pre-wrap leading-relaxed mb-4">{post.content}</p>
          <div className="flex items-center justify-between text-xs text-muted-foreground">
            <span>{post.display_name || "Anonymous"} · {timeAgo(post.created_date)}</span>
            <div className="flex gap-3">
              {!isAdmin && !post.flagged && !reported && (
                <button
                  onClick={handleReportPost}
                  disabled={reporting}
                  className="text-muted-foreground hover:text-vida-clay transition-colors flex items-center gap-1"
                >
                  <Flag className="w-3.5 h-3.5" /> {reporting ? "Reporting…" : "Report"}
                </button>
              )}
              {reported && <span className="text-xs text-muted-foreground">Reported to moderators</span>}
              {isAdmin && (
                <div className="flex gap-3">
                  <button onClick={handleTogglePostStatus} className="text-muted-foreground hover:text-primary transition-colors flex items-center gap-1">
                    {post.status === "active" ? <><EyeOff className="w-3.5 h-3.5" /> Hide</> : <><Eye className="w-3.5 h-3.5" /> Show</>}
                  </button>
                  <button onClick={handleDeletePost} className="text-muted-foreground hover:text-destructive transition-colors flex items-center gap-1">
                    <Trash2 className="w-3.5 h-3.5" /> Delete
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Replies */}
        <div className="border-t border-border pt-5">
          <h3 className="font-heading text-lg text-primary mb-4">
            {replies.length} {replies.length === 1 ? "reply" : "replies"}
          </h3>
          {loadingReplies ? (
            <div className="flex justify-center py-6"><Loader /></div>
          ) : replies.length === 0 ? (
            <p className="text-sm text-muted-foreground mb-5">No replies yet. Be the first to respond.</p>
          ) : (
            <div className="space-y-3 mb-5">
              {replies.map((r) => (
                <div key={r.id} className={`rounded-xl border p-4 ${r.status === "hidden" ? "bg-muted/30 border-border opacity-60" : "bg-background border-border"}`}>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-medium text-muted-foreground">
                      {r.display_name || "Anonymous"} · {timeAgo(r.created_date)}
                    </span>
                    <div className="flex gap-2">
                      {r.flagged && (
                        <span className="text-xs text-vida-clay flex items-center gap-1">
                          <Flag className="w-3 h-3" /> Reported
                        </span>
                      )}
                      {!isAdmin && !r.flagged && (
                        <button onClick={() => handleReportReply(r.id)} className="text-xs text-muted-foreground hover:text-vida-clay transition-colors flex items-center gap-1">
                          <Flag className="w-3 h-3" /> Report
                        </button>
                      )}
                      {isAdmin && (
                        <div className="flex gap-2">
                          <button onClick={() => handleToggleReplyStatus(r)} className="text-xs text-muted-foreground hover:text-primary transition-colors flex items-center gap-1">
                            {r.status === "active" ? <><EyeOff className="w-3 h-3" /> Hide</> : <><Eye className="w-3 h-3" /> Show</>}
                          </button>
                          <button onClick={() => handleDeleteReply(r.id)} className="text-xs text-muted-foreground hover:text-destructive transition-colors flex items-center gap-1">
                            <Trash2 className="w-3 h-3" /> Delete
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                  <p className="text-sm text-foreground whitespace-pre-wrap">{r.content}</p>
                </div>
              ))}
            </div>
          )}

          {post.status === "active" && (
            <div className="bg-muted/30 rounded-xl p-4">
              <ReplyForm postId={post.id} onReplyAdded={handleReplyAdded} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}