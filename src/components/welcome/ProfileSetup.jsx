import React, { useState, useEffect } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import { Switch } from "@/components/ui/switch";
import { Bell, BookOpen, Loader2 } from "lucide-react";

export default function ProfileSetup({ onComplete }) {
  const { checkUserAuth } = useAuth();
  const [reminderEnabled, setReminderEnabled] = useState(true);
  const [contentUpdates, setContentUpdates] = useState(true);
  const [time, setTime] = useState("09:00");
  const [timezone, setTimezone] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    try {
      setTimezone(Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC");
    } catch {
      setTimezone("UTC");
    }
  }, []);

  const handleSave = async () => {
    setSaving(true);
    try {
      await base44.auth.updateMe({
        reminder_enabled: reminderEnabled,
        content_updates_enabled: contentUpdates,
        reminder_time: time,
        reminder_timezone: timezone,
      });
      await checkUserAuth();
    } catch (e) {
      console.error("Profile setup save failed", e);
    }
    setSaving(false);
    onComplete();
  };

  return (
    <div className="max-w-lg mx-auto">
      <div className="text-center mb-8">
        <div className="eyebrow mb-2">Step 2 · Set your rhythm</div>
        <h2 className="font-heading text-3xl text-primary">When should we reach you?</h2>
        <p className="text-muted-foreground mt-2">Gentle reminders keep your tracking consistent. You can change these anytime in Daily Signals.</p>
      </div>

      <div className="rounded-3xl bg-card border border-border p-6 sm:p-8 space-y-1">
        <div className="flex items-start justify-between gap-4 py-4 border-b border-border">
          <div className="flex-1">
            <p className="text-sm font-medium text-primary flex items-center gap-2">
              <Bell className="w-3.5 h-3.5" strokeWidth={1.5} /> Daily check-in reminder
            </p>
            <p className="text-xs text-muted-foreground mt-1">A daily email nudging you to log your signals.</p>
          </div>
          <Switch checked={reminderEnabled} onCheckedChange={setReminderEnabled} />
        </div>

        <div className="flex items-start justify-between gap-4 py-4 border-b border-border">
          <div className="flex-1">
            <p className="text-sm font-medium text-primary flex items-center gap-2">
              <BookOpen className="w-3.5 h-3.5" strokeWidth={1.5} /> New content notifications
            </p>
            <p className="text-xs text-muted-foreground mt-1">A digest when new reports or explainers are published.</p>
          </div>
          <Switch checked={contentUpdates} onCheckedChange={setContentUpdates} />
        </div>

        <div className="py-4">
          <label className="block text-sm font-medium text-primary mb-2">Preferred reminder time</label>
          <div className="flex flex-col sm:flex-row gap-3">
            <input
              type="time"
              value={time}
              onChange={(e) => setTime(e.target.value)}
              className="px-4 py-2.5 rounded-xl border border-input bg-card text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent"
            />
            <div className="px-4 py-2.5 rounded-xl border border-border bg-muted/50 text-sm text-muted-foreground flex items-center gap-2">
              <span className="text-xs uppercase tracking-wide">Timezone</span>
              <span className="text-primary font-medium">{timezone?.replace(/_/g, " ")}</span>
            </div>
          </div>
        </div>
      </div>

      <button
        onClick={handleSave}
        disabled={saving}
        className="w-full mt-6 inline-flex items-center justify-center gap-2 rounded-full px-8 py-3.5 bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-60"
      >
        {saving ? <><Loader2 className="w-4 h-4 animate-spin" /> Saving…</> : "Continue →"}
      </button>
    </div>
  );
}