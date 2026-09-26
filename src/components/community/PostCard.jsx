import React from "react";
import { Flag, EyeOff, Eye, Trash2, MessageCircle } from "lucide-react";
import { categoryLabel } from "@/data/communityCategories";

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

export default function PostCard({ post, replyCount, onOpen, onReport, isAdmin, onToggleStatus, onDelete }) {
  return (
    <div
      className="rounded-2xl bg-card border border-border p-5 hover:border-primary/30 transition-colors cursor-pointer"
      onClick={() => onOpen(post)}
    >
      <div className="flex items-center gap-2 mb-2 flex-wrap">
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
      <h3 className="font-heading text-xl text-primary mb-2 line-clamp-2">{post.title}</h3>
      <p className="text-sm text-muted-foreground line-clamp-2 mb-3 whitespace-pre-wrap">{post.content}</p>
      <div className="flex items-center justify-between text-xs text-muted-foreground">
        <span>{post.display_name || "Anonymous"}</span>
        <span>{timeAgo(post.created_date)}</span>
      </div>
      <div className="flex items-center gap-3 mt-3 pt-3 border-t border-border/60 text-xs text-muted-foreground">
        <span className="flex items-center gap-1">
          <MessageCircle className="w-3.5 h-3.5" /> {replyCount} {replyCount === 1 ? "reply" : "replies"}
        </span>
        {!isAdmin && !post.flagged && (
          <button
            onClick={(e) => { e.stopPropagation(); onReport(post); }}
            className="ml-auto text-muted-foreground hover:text-vida-clay transition-colors flex items-center gap-1"
          >
            <Flag className="w-3.5 h-3.5" /> Report
          </button>
        )}
        {isAdmin && (
          <div className="ml-auto flex gap-3" onClick={(e) => e.stopPropagation()}>
            <button
              onClick={() => onToggleStatus(post)}
              className="text-muted-foreground hover:text-primary transition-colors flex items-center gap-1"
            >
              {post.status === "active" ? <><EyeOff className="w-3.5 h-3.5" /> Hide</> : <><Eye className="w-3.5 h-3.5" /> Show</>}
            </button>
            <button
              onClick={() => onDelete(post)}
              className="text-muted-foreground hover:text-destructive transition-colors flex items-center gap-1"
            >
              <Trash2 className="w-3.5 h-3.5" /> Delete
            </button>
          </div>
        )}
      </div>
    </div>
  );
}