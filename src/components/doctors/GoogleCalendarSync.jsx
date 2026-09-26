import React, { useState } from "react";
import { base44 } from "@/api/base44Client";
import { CalendarCheck, Loader2, Link2, Check } from "lucide-react";

const CONNECTOR_ID = "6aaf624372f1397928edeb5e";

export default function GoogleCalendarSync({ appointment }) {
  const [syncing, setSyncing] = useState(false);
  const [needsConnect, setNeedsConnect] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState(null);

  const handleSync = async () => {
    setSyncing(true);
    setSuccess(false);
    setError(null);
    try {
      await base44.functions.invoke("add-google-calendar-event", {
        appointmentId: appointment.id,
      });
      setSuccess(true);
      setNeedsConnect(false);
    } catch (e) {
      const status = e?.response?.status;
      if (status === 403) {
        setNeedsConnect(true);
      } else {
        setError("Failed to sync. Please try again.");
      }
    } finally {
      setSyncing(false);
    }
  };

  const handleConnect = async () => {
    try {
      const url = await base44.connectors.connectAppUser(CONNECTOR_ID);
      const popup = window.open(url, "_blank");
      const timer = setInterval(() => {
        if (!popup || popup.closed) {
          clearInterval(timer);
          handleSync();
        }
      }, 500);
    } catch (e) {
      setError("Failed to connect. Please try again.");
    }
  };

  if (success) {
    return (
      <span className="inline-flex items-center gap-1 text-xs text-vida-moss">
        <Check className="w-3 h-3" /> Added to Google Calendar
      </span>
    );
  }

  return (
    <div className="flex flex-col gap-1">
      <button
        onClick={handleSync}
        disabled={syncing}
        className="inline-flex items-center gap-1 text-xs text-vida-moss hover:text-primary transition-colors disabled:opacity-50"
      >
        {syncing ? (
          <Loader2 className="w-3 h-3 animate-spin" />
        ) : (
          <CalendarCheck className="w-3 h-3" />
        )}
        Add to Google Calendar
      </button>
      {needsConnect && (
        <button
          onClick={handleConnect}
          className="inline-flex items-center gap-1 text-xs text-accent-foreground hover:text-primary transition-colors"
        >
          <Link2 className="w-3 h-3" /> Connect your Google Calendar first
        </button>
      )}
      {error && <span className="text-xs text-destructive">{error}</span>}
    </div>
  );
}