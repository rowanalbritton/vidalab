import React, { useState } from "react";
import { base44 } from "@/api/base44Client";
import { Calendar, Check, Loader2, Link2 } from "lucide-react";

const CALENDAR_CONNECTOR_ID = "6aaf624372f1397928edeb5e";

export default function CheckinCalendarButton({ checkinId }) {
  const [status, setStatus] = useState("idle");
  const [eventLink, setEventLink] = useState(null);

  const handleSync = async () => {
    setStatus("loading");
    try {
      const res = await base44.functions.invoke("sync-checkin-to-calendar", { checkinId });
      setEventLink(res.data.htmlLink);
      setStatus("success");
    } catch (err) {
      const msg = err?.response?.data?.error || err?.message || "";
      if (msg.includes("not connected") || err?.response?.status === 403) {
        setStatus("needsConnect");
      } else {
        setStatus("error");
      }
    }
  };

  const handleConnect = async () => {
    setStatus("loading");
    try {
      const url = await base44.connectors.connectAppUser(CALENDAR_CONNECTOR_ID);
      const popup = window.open(url, "_blank");
      const timer = setInterval(() => {
        if (!popup || popup.closed) {
          clearInterval(timer);
          handleSync();
        }
      }, 600);
    } catch (e) {
      setStatus("error");
    }
  };

  if (status === "success") {
    return (
      <div className="inline-flex items-center gap-2 text-sm" style={{ color: "var(--moss)" }}>
        <Check className="w-4 h-4" /> Added to Google Calendar
        {eventLink && (
          <a href={eventLink} target="_blank" rel="noopener noreferrer" className="underline" style={{ color: "var(--moss)" }}>
            View event
          </a>
        )}
      </div>
    );
  }

  if (status === "needsConnect") {
    return (
      <button
        onClick={handleConnect}
        className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full text-sm font-medium transition-colors"
        style={{ background: "transparent", color: "var(--forest)", border: "1px solid var(--line)" }}
      >
        <Link2 className="w-4 h-4" /> Connect Google Calendar
      </button>
    );
  }

  return (
    <button
      onClick={handleSync}
      disabled={status === "loading"}
      className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full text-sm font-medium transition-colors disabled:opacity-50"
      style={{ background: "transparent", color: "var(--forest)", border: "1px solid var(--line)" }}
    >
      {status === "loading" ? <Loader2 className="w-4 h-4 animate-spin" /> : <Calendar className="w-4 h-4" />}
      Add to Google Calendar
    </button>
  );
}