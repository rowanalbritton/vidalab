import React, { useState } from "react";
import { Button } from "@/components/ui/button";
import { Loader2 } from "lucide-react";
import { base44 } from "@/api/base44Client";

export default function ReplyForm({ postId, onReplyAdded }) {
  const [form, setForm] = useState({
    display_name: "Anonymous",
    content: "",
  });
  const [saving, setSaving] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    const content = form.content.trim();
    if (content.length < 1) return;
    setSaving(true);
    try {
      const reply = await base44.entities.CommunityReply.create({
        post_id: postId,
        display_name: form.display_name.trim() || "Anonymous",
        content,
        status: "active",
        flagged: false,
      });
      onReplyAdded(reply);
      setForm((f) => ({ ...f, content: "" }));
    } catch (e) {
      console.error(e);
    } finally {
      setSaving(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <input
        type="text"
        value={form.display_name}
        onChange={(e) => setForm((f) => ({ ...f, display_name: e.target.value }))}
        maxLength={50}
        placeholder="Anonymous"
        className="w-40 px-3 py-2 rounded-lg border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent"
      />
      <textarea
        value={form.content}
        onChange={(e) => setForm((f) => ({ ...f, content: e.target.value }))}
        rows={3}
        maxLength={2000}
        placeholder="Add a supportive reply…"
        className="w-full px-4 py-2.5 rounded-xl border border-input bg-background text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent resize-none"
      />
      <div className="flex justify-end">
        <Button type="submit" disabled={saving || !form.content.trim()} className="rounded-full px-5 text-sm">
          {saving ? <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> Replying…</> : "Reply"}
        </Button>
      </div>
    </form>
  );
}