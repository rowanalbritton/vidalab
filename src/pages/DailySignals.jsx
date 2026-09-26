import React, { useState, useEffect, useCallback } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import DailyCheckinForm from "@/components/DailyCheckinForm";
import InsightCard from "@/components/InsightCard";
import MoodEnergyChart from "@/components/MoodEnergyChart";
import SleepMoodChart from "@/components/SleepMoodChart";
import VidaRewind from "@/components/vida-rewind/VidaRewind";
import ReminderSettings from "@/components/ReminderSettings";
import CheckinCalendarButton from "@/components/CheckinCalendarButton";
import GoogleSyncButton from "@/components/GoogleSyncButton";
import MonthlyReportButton from "@/components/MonthlyReportButton";
import ExportHealthDataButton from "@/components/ExportHealthDataButton";
import PracticeCorrelation from "@/components/PracticeCorrelation";
import BodyWeatherCard from "@/components/BodyWeatherCard";
import { summarize } from "@/lib/insights";
import { Calendar, Lock, Sparkles, FileSpreadsheet, HardDrive } from "lucide-react";
import Loader from "@/components/Loader";

export default function DailySignals() {
  const { user, checkUserAuth } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";
  const [checkins, setCheckins] = useState([]);
  const [loading, setLoading] = useState(true);
  const [lastInsight, setLastInsight] = useState(null);
  const [error, setError] = useState(null);
  const [showRewind, setShowRewind] = useState(false);
  const [lastCheckinId, setLastCheckinId] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const items = await base44.entities.DailyCheckin.list("-checkin_date", 200);
      setCheckins(items);
    } catch (e) {
      setError("We couldn't load your history. Please try again.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    if (!user || loading || checkins.length < 10) return;
    const now = new Date();
    const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
    const lastRewind = user.last_rewind_date?.slice(0, 7);
    if (lastRewind !== currentMonth) {
      const cutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      const recentCount = checkins.filter(
        (c) => new Date(c.checkin_date.slice(0, 10) + "T00:00:00") >= cutoff
      ).length;
      if (recentCount >= 10) setShowRewind(true);
    }
  }, [user, loading, checkins]);

  const handleRewindClose = async () => {
    setShowRewind(false);
    try {
      const today = new Date().toISOString().slice(0, 10);
      await base44.auth.updateMe({ last_rewind_date: today });
      await checkUserAuth();
    } catch (e) {
      console.error("Failed to save rewind date", e);
    }
  };

  const handleSaved = async (payload) => {
    const created = await base44.entities.DailyCheckin.create(payload);
    setCheckins((prev) => [created, ...prev].sort((a, b) => (a.checkin_date < b.checkin_date ? 1 : -1)));
    setLastInsight(created.insight);
    setLastCheckinId(created.id);
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const historyLimit = isVidaPlus ? checkins.length : 30;
  const visibleCheckins = checkins.slice(0, historyLimit);

  return (
    <main className="max-w-5xl mx-auto px-5 sm:px-8 py-10">
      <div className="mb-10">
        <span className="text-xs uppercase tracking-widest text-muted-foreground">Daily Signals</span>
        <h1 className="font-heading text-4xl text-primary mt-1">Today's check-in</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">A few taps a day. Each one returns a small, relevant insight — and adds a dot to your pattern.</p>
      </div>

      {lastInsight && (
        <div className="mb-8">
          <InsightCard insight={lastInsight} />
          {lastCheckinId && (
            <div className="mt-4">
              <CheckinCalendarButton checkinId={lastCheckinId} />
            </div>
          )}
        </div>
      )}

      <BodyWeatherCard />

      <div className="rounded-3xl bg-card border border-border p-6 sm:p-8 mb-12">
        <DailyCheckinForm onSaved={handleSaved} />
      </div>

      <div>
        <div className="flex flex-wrap items-center justify-between gap-3 mb-5">
          <div className="flex items-baseline gap-3">
            <h2 className="font-heading text-2xl text-primary">Your history</h2>
            <span className="text-sm text-muted-foreground">{checkins.length} {checkins.length === 1 ? "entry" : "entries"}</span>
          </div>
          <div className="flex flex-wrap gap-2">
            {checkins.length > 0 && <MonthlyReportButton checkins={checkins} user={user} />}
            <ExportHealthDataButton />
            {checkins.length > 0 && (
              <GoogleSyncButton
                connectorId="6ab20846a57ea61357fd535a"
                functionName="export-to-google-sheets"
                label="Export to Google Sheets"
                connectLabel="Connect Google Sheets"
                successLabel="Spreadsheet created"
                successUrlKey="url"
                icon={FileSpreadsheet}
              />
            )}
            {checkins.length > 0 && (
              <GoogleSyncButton
                connectorId="6ab2085199c20e180bff3ebf"
                functionName="save-snapshot-to-drive"
                label="Save snapshot to Drive"
                connectLabel="Connect Google Drive"
                successLabel="Snapshot saved to Drive"
                successUrlKey="url"
                icon={HardDrive}
              />
            )}
            {checkins.length >= 10 && (
              <button
                onClick={() => setShowRewind(true)}
                className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
              >
                <Sparkles className="w-4 h-4" /> Lab Notes
              </button>
            )}
          </div>
        </div>

        {!loading && checkins.length > 0 && (
          <div className="mb-8">
            <MoodEnergyChart checkins={checkins} />
          </div>
        )}

        {!loading && checkins.length > 0 && (
          <div className="mb-8">
            <SleepMoodChart checkins={checkins} />
          </div>
        )}

        {!loading && checkins.length > 0 && (
          <div className="mb-8">
            <PracticeCorrelation checkins={checkins} />
          </div>
        )}

        {!isVidaPlus && checkins.length > 30 && (
          <div className="flex items-center gap-2 text-sm text-muted-foreground bg-vida-blush/30 border border-vida-blush rounded-xl px-4 py-3 mb-4">
            <Lock className="w-4 h-4 text-primary" />
            Showing your latest 30 entries. Vida+ unlocks unlimited history.
          </div>
        )}

        {loading ? (
          <div className="flex justify-center py-12"><Loader /></div>
        ) : visibleCheckins.length === 0 ? (
          <div className="text-center py-12 rounded-2xl border border-dashed border-border">
            <Calendar className="w-8 h-8 text-muted-foreground mx-auto mb-3" strokeWidth={1} />
            <p className="text-muted-foreground text-sm">No entries yet. Your first check-in above starts your pattern.</p>
          </div>
        ) : (
          <div className="space-y-2">
            {visibleCheckins.map((c) => (
              <div key={c.id} className="rounded-xl bg-card border border-border p-4 hover:border-primary/30 transition-colors">
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-primary">
                      {new Date(c.checkin_date.slice(0, 10) + "T00:00:00").toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })}
                    </p>
                    <p className="text-sm text-muted-foreground mt-0.5">{summarize(c)}</p>
                    {c.notes && <p className="text-xs text-muted-foreground mt-2 italic line-clamp-2">"{c.notes}"</p>}
                  </div>
                  <div className="flex flex-col items-end gap-1 shrink-0">
                    <span className="text-xs text-muted-foreground">Energy</span>
                    <span className="font-heading text-lg text-primary">{c.energy}/5</span>
                  </div>
                </div>
                {c.insight && (
                  <p className="text-xs text-muted-foreground mt-3 pt-3 border-t border-border/60 font-display text-sm leading-relaxed">
                    {c.insight}
                  </p>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {showRewind && (
        <VidaRewind checkins={checkins} user={user} onClose={handleRewindClose} />
      )}

      <div className="mt-12">
        <ReminderSettings />
      </div>
    </main>
  );
}