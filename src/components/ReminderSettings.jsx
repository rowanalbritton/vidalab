import React, { useState, useEffect } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import { Switch } from "@/components/ui/switch";
import { Bell, BookOpen, Loader2, Check } from "lucide-react";

export default function ReminderSettings() {
  const { user, checkUserAuth } = useAuth();
  const [reminderEnabled, setReminderEnabled] = useState(user?.reminder_enabled || false);
  const [contentUpdates, setContentUpdates] = useState(user?.content_updates_enabled || false);
  const [time, setTime] = useState(user?.reminder_time || "09:00");
  const [timezone, setTimezone] = useState(user?.reminder_timezone || "");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (!timezone) {
      try {
        setTimezone(Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC");
      } catch {
        setTimezone("UTC");
      }
    }
  }, [timezone]);

  const handleSave = async () => {
    setSaving(true);
    setSaved(false);
    try {
      await base44.auth.updateMe({
        reminder_enabled: reminderEnabled,
        content_updates_enabled: contentUpdates,
        reminder_time: time,
        reminder_timezone: timezone,
      });
      await checkUserAuth();
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (e) {
      console.error("ReminderSettings: save failed", e);
    }
    setSaving(false);
  };

  const formatTimezone = (tz) => {
    try {
      return tz.replace(/_/g, " ");
    } catch {
      return tz;
    }
  };

  return (
    <div className="rounded-3xl bg-card border border-border p-6 sm:p-8">
      <div className="flex items-center gap-2 mb-1">
        <Bell className="w-4 h-4 text-muted-foreground" strokeWidth={1.5} />
        <span className="text-xs uppercase tracking-widest text-muted-foreground">Email Reminders</span>
      </div>
      <h2 className="font-heading text-2xl text-primary mb-1">Stay in the rhythm</h2>
      <p className="text-sm text-muted-foreground mb-6 max-w-md">Get a gentle nudge to check in, and a note when new research joins the library.</p>

      {/* Daily check-in reminder */}
      <div className="flex items-start justify-between gap-4 py-4 border-t border-border">
        <div className="flex-1">
          <p className="text-sm font-medium text-primary flex items-center gap-2">
            <Bell className="w-3.5 h-3.5" strokeWidth={1.5} /> Daily check-in reminder
          </p>
          <p className="text-xs text-muted-foreground mt-1">A daily email reminding you to log your signals.</p>
        </div>
        <Switch checked={reminderEnabled} onCheckedChange={setReminderEnabled} />
      </div>

      {/* New content notifications */}
      <div className="flex items-start justify-between gap-4 py-4 border-t border-border">
        <div className="flex-1">
          <p className="text-sm font-medium text-primary flex items-center gap-2">
            <BookOpen className="w-3.5 h-3.5" strokeWidth={1.5} /> New content notifications
          </p>
          <p className="text-xs text-muted-foreground mt-1">A digest when new reports, explainers, or articles are published.</p>
        </div>
        <Switch checked={contentUpdates} onCheckedChange={setContentUpdates} />
      </div>

      {/* Time + timezone */}
      <div className="py-4 border-t border-border">
        <label className="block text-sm font-medium text-primary mb-2">Preferred time</label>
        <div className="flex flex-col sm:flex-row gap-3">
          <input
            type="time"
            value={time}
            onChange={(e) => setTime(e.target.value)}
            className="px-4 py-2.5 rounded-xl border border-input bg-card text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-accent"
          />
          <div className="px-4 py-2.5 rounded-xl border border-border bg-muted/50 text-sm text-muted-foreground flex items-center gap-2">
            <span className="text-xs uppercase tracking-wide">Your timezone</span>
            <span className="text-primary font-medium">{formatTimezone(timezone)}</span>
          </div>
        </div>
        <p className="text-xs text-muted-foreground mt-2">Reminders arrive at this time in your local timezone. We detected it from your browser — adjust if needed.</p>
      </div>

      {/* Save */}
      <div className="flex items-center gap-3 mt-4">
        <button
          onClick={handleSave}
          disabled={saving}
          className="inline-flex items-center gap-2 px-6 py-2.5 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-60"
        >
          {saving ? <><Loader2 className="w-4 h-4 animate-spin" /> Saving…</> : "Save preferences"}
        </button>
        {saved && (
          <span className="text-sm text-muted-foreground flex items-center gap-1.5">
            <Check className="w-4 h-4 text-primary" /> Saved
          </span>
        )}
      </div>
    </div>
  );
}