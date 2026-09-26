import React, { useState, useEffect } from "react";
import { base44 } from "@/api/base44Client";
import { buildHealthSnapshot } from "@/lib/healthSnapshot";
import {
  X,
  Loader2,
  CheckCircle2,
  FileText,
  Mail,
  Sparkles,
  CalendarCheck,
  CalendarPlus,
} from "lucide-react";

export default function BookingModal({ doctor, onClose, onBooked }) {
  const [date, setDate] = useState("");
  const [time, setTime] = useState("");
  const [reason, setReason] = useState("");
  const [notes, setNotes] = useState("");
  const [includeSnapshot, setIncludeSnapshot] = useState(true);
  const [snapshot, setSnapshot] = useState(null);
  const [loadingSnapshot, setLoadingSnapshot] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [snapshotSent, setSnapshotSent] = useState(false);
  const [calendarSynced, setCalendarSynced] = useState(false);
  const [needsCalendarConnect, setNeedsCalendarConnect] = useState(false);
  const [appointmentId, setAppointmentId] = useState(null);
  const [error, setError] = useState("");

  const CALENDAR_CONNECTOR_ID = "6aaf624372f1397928edeb5e";
  const today = new Date().toISOString().split("T")[0];
  const canSendSnapshot = !!(snapshot && doctor.email);

  useEffect(() => {
    base44.entities.DailyCheckin
      .list("-checkin_date", 500)
      .then((checkins) => setSnapshot(buildHealthSnapshot(checkins)))
      .catch(() => setSnapshot(null))
      .finally(() => setLoadingSnapshot(false));
  }, []);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!date || !time) {
      setError("Please select a date and time.");
      return;
    }
    setSubmitting(true);
    setError("");
    try {
      let sent = false;

      // Send snapshot to practice if requested and possible
      if (includeSnapshot && canSendSnapshot) {
        try {
          const res = await base44.functions.invoke("send-appointment-snapshot", {
            doctorId: doctor.id,
            appointmentDate: date,
            appointmentTime: time,
            reason: reason || "",
            snapshot,
          });
          if (res?.data?.status === "sent") sent = true;
        } catch (_) {
          // Email failed — appointment still proceeds
        }
      }

      const apt = await base44.entities.Appointment.create({
        doctor_id: doctor.id,
        doctor_name: doctor.practice_name,
        practice_name: doctor.practice_name,
        specialty: doctor.specialty || "",
        appointment_date: date,
        appointment_time: time,
        reason: reason || "",
        notes: notes || "",
        status: "requested",
        snapshot_sent: sent,
      });

      setSnapshotSent(sent);
      setAppointmentId(apt.id);

      // Auto-add to Google Calendar if the user has connected their account
      let calendarNeedsConnect = false;
      try {
        await base44.functions.invoke("add-google-calendar-event", {
          appointmentId: apt.id,
        });
        setCalendarSynced(true);
      } catch (calErr) {
        if (calErr?.response?.status === 403) {
          calendarNeedsConnect = true;
          setNeedsCalendarConnect(true);
        }
      }

      setSuccess(true);
      if (!calendarNeedsConnect) {
        setTimeout(() => {
          onBooked();
          onClose();
        }, 1800);
      }
    } catch (err) {
      setError("Could not book the appointment. Please try again.");
      setSubmitting(false);
    }
  };

  const handleConnectCalendar = async () => {
    try {
      const url = await base44.connectors.connectAppUser(CALENDAR_CONNECTOR_ID);
      const popup = window.open(url, "_blank");
      const timer = setInterval(async () => {
        if (!popup || popup.closed) {
          clearInterval(timer);
          try {
            await base44.functions.invoke("add-google-calendar-event", {
              appointmentId,
            });
            setCalendarSynced(true);
            setNeedsCalendarConnect(false);
            setTimeout(() => {
              onBooked();
              onClose();
            }, 1500);
          } catch (_) {
            // sync still failed — leave the connect prompt visible
          }
        }
      }, 800);
    } catch (_) {
      // connection attempt failed
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="bg-card rounded-2xl border border-border max-w-md w-full p-6 shadow-xl animate-fade-in max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        {success ? (
          <div className="text-center py-8">
            <CheckCircle2 className="w-12 h-12 text-vida-moss mx-auto mb-4" strokeWidth={1.5} />
            <h3 className="font-heading text-xl text-primary mb-2">Appointment Requested</h3>
            <p className="text-sm text-muted-foreground">
              Your appointment with {doctor.practice_name} has been saved to your appointments.
            </p>
            {snapshotSent && (
              <p className="text-xs text-vida-moss mt-3 inline-flex items-center gap-1.5">
                <Mail className="w-3.5 h-3.5" /> Health snapshot sent to the practice
              </p>
            )}
            {calendarSynced && (
              <p className="text-xs text-vida-moss mt-3 inline-flex items-center gap-1.5">
                <CalendarCheck className="w-3.5 h-3.5" /> Added to your Google Calendar
              </p>
            )}
            {needsCalendarConnect && (
              <div className="mt-4 space-y-2.5">
                <p className="text-xs text-muted-foreground">
                  Connect Google Calendar to auto-add this appointment with all details.
                </p>
                <button
                  onClick={handleConnectCalendar}
                  type="button"
                  className="inline-flex items-center gap-1.5 text-xs text-primary font-medium hover:underline"
                >
                  <CalendarPlus className="w-3.5 h-3.5" /> Connect Google Calendar
                </button>
                <button
                  onClick={() => {
                    onBooked();
                    onClose();
                  }}
                  type="button"
                  className="block text-xs text-muted-foreground hover:text-primary transition-colors"
                >
                  Skip for now
                </button>
              </div>
            )}
          </div>
        ) : (
          <>
            <div className="flex items-start justify-between mb-5">
              <div>
                <h3 className="font-heading text-xl text-primary">Book Appointment</h3>
                <p className="text-sm text-muted-foreground mt-1">{doctor.practice_name}</p>
                {doctor.specialty && (
                  <p className="text-xs text-muted-foreground">{doctor.specialty}</p>
                )}
              </div>
              <button
                onClick={onClose}
                className="text-muted-foreground hover:text-primary transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs uppercase tracking-widest text-muted-foreground mb-1.5">
                    Date
                  </label>
                  <input
                    type="date"
                    min={today}
                    value={date}
                    onChange={(e) => setDate(e.target.value)}
                    required
                    className="w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm focus:outline-none focus:border-primary"
                  />
                </div>
                <div>
                  <label className="block text-xs uppercase tracking-widest text-muted-foreground mb-1.5">
                    Time
                  </label>
                  <input
                    type="time"
                    value={time}
                    onChange={(e) => setTime(e.target.value)}
                    required
                    className="w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm focus:outline-none focus:border-primary"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs uppercase tracking-widest text-muted-foreground mb-1.5">
                  Reason for Visit
                </label>
                <textarea
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  rows={2}
                  placeholder="What would you like to discuss?"
                  className="w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm focus:outline-none focus:border-primary resize-none"
                />
              </div>

              <div>
                <label className="block text-xs uppercase tracking-widest text-muted-foreground mb-1.5">
                  Notes
                </label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  rows={2}
                  placeholder="Any additional information for the practice"
                  className="w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm focus:outline-none focus:border-primary resize-none"
                />
              </div>

              {/* Snapshot section */}
              {loadingSnapshot ? (
                <div className="flex items-center gap-2 text-sm text-muted-foreground py-2">
                  <Loader2 className="w-4 h-4 animate-spin" /> Loading your health snapshot…
                </div>
              ) : !snapshot ? (
                <div className="rounded-xl bg-muted/50 border border-border p-3.5 flex items-start gap-2.5">
                  <FileText className="w-4 h-4 text-muted-foreground shrink-0 mt-0.5" strokeWidth={1.5} />
                  <p className="text-xs text-muted-foreground leading-relaxed">
                    Track a few daily check-ins to include your Vida Health Snapshot with this request.
                  </p>
                </div>
              ) : !doctor.email ? (
                <div className="rounded-xl bg-muted/50 border border-border p-3.5 flex items-start gap-2.5">
                  <FileText className="w-4 h-4 text-muted-foreground shrink-0 mt-0.5" strokeWidth={1.5} />
                  <p className="text-xs text-muted-foreground leading-relaxed">
                    This practice doesn't have an email on file, so your snapshot can't be sent directly.
                    Your appointment request will still be saved.
                  </p>
                </div>
              ) : (
                <div className="rounded-xl bg-accent/10 border border-accent/30 p-4">
                  <label className="flex items-start gap-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={includeSnapshot}
                      onChange={(e) => setIncludeSnapshot(e.target.checked)}
                      className="mt-0.5 w-4 h-4 rounded border-border text-primary focus:ring-primary shrink-0"
                    />
                    <div>
                      <div className="flex items-center gap-1.5">
                        <Sparkles className="w-3.5 h-3.5 text-vida-moss" strokeWidth={1.5} />
                        <span className="text-sm font-medium text-primary">
                          Send my Vida Health Snapshot
                        </span>
                      </div>
                      <p className="text-xs text-muted-foreground mt-1 leading-relaxed">
                        Emails your tracking summary — {snapshot.total} check-ins, key metrics, top
                        symptoms, and questions — directly to {doctor.practice_name}.
                      </p>
                    </div>
                  </label>

                  {includeSnapshot && (
                    <div className="mt-3 pt-3 border-t border-accent/20 grid grid-cols-3 gap-2">
                      <div className="text-center">
                        <p className="text-[10px] uppercase tracking-widest text-muted-foreground">Energy</p>
                        <p className="font-heading text-base text-primary">{snapshot.avgEnergy}/5</p>
                      </div>
                      <div className="text-center">
                        <p className="text-[10px] uppercase tracking-widest text-muted-foreground">Sleep</p>
                        <p className="font-heading text-base text-primary">
                          {snapshot.avgSleep ? `${snapshot.avgSleep}h` : "—"}
                        </p>
                      </div>
                      <div className="text-center">
                        <p className="text-[10px] uppercase tracking-widest text-muted-foreground">Check-ins</p>
                        <p className="font-heading text-base text-primary">{snapshot.total}</p>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {error && <p className="text-sm text-destructive">{error}</p>}

              <div className="flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={onClose}
                  className="flex-1 px-4 py-2.5 rounded-full border border-border text-sm font-medium text-muted-foreground hover:bg-muted transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-50"
                >
                  {submitting ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    "Request Appointment"
                  )}
                </button>
              </div>
            </form>
          </>
        )}
      </div>
    </div>
  );
}