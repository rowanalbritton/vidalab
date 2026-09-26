import React from "react";
import { Calendar, Clock, X, Mail, CalendarPlus } from "lucide-react";
import Loader from "@/components/Loader";
import { downloadAppointmentICS } from "@/lib/calendarSync";
import GoogleCalendarSync from "./GoogleCalendarSync";

const STATUS_STYLES = {
  requested: "bg-vida-sky/30 text-vida-sky-deep",
  confirmed: "bg-vida-moss/15 text-vida-moss",
  cancelled: "bg-destructive/10 text-destructive",
  completed: "bg-muted text-muted-foreground",
};

export default function MyAppointments({ appointments, onCancel, loading }) {
  if (loading) {
    return (
      <div className="flex items-center justify-center py-4">
        <Loader label="Loading appointments…" />
      </div>
    );
  }

  const upcoming = appointments
    .filter((a) => a.status !== "cancelled" && a.status !== "completed")
    .sort(
      (a, b) =>
        new Date(a.appointment_date + "T" + (a.appointment_time || "00:00")) -
        new Date(b.appointment_date + "T" + (b.appointment_time || "00:00"))
    );

  if (upcoming.length === 0) return null;

  return (
    <div className="mb-8">
      <h2 className="font-heading text-2xl text-primary mb-4">My Appointments</h2>
      <div className="grid sm:grid-cols-2 gap-3">
        {upcoming.map((apt) => (
          <div key={apt.id} className="rounded-2xl bg-card border border-border p-4">
            <div className="flex items-start justify-between gap-2 mb-2">
              <div>
                <h3 className="font-heading text-base text-primary leading-tight">
                  {apt.practice_name || apt.doctor_name}
                </h3>
                {apt.specialty && (
                  <p className="text-xs text-muted-foreground mt-0.5">{apt.specialty}</p>
                )}
              </div>
              <span
                className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium shrink-0 ${
                  STATUS_STYLES[apt.status] || ""
                }`}
              >
                {apt.status}
              </span>
            </div>

            <div className="flex items-center gap-3 text-sm text-muted-foreground mb-2">
              <span className="inline-flex items-center gap-1">
                <Calendar className="w-3.5 h-3.5" /> {apt.appointment_date}
              </span>
              <span className="inline-flex items-center gap-1">
                <Clock className="w-3.5 h-3.5" /> {apt.appointment_time}
              </span>
            </div>

            {apt.reason && (
              <p className="text-xs text-muted-foreground mb-2 leading-relaxed">{apt.reason}</p>
            )}

            {apt.snapshot_sent && (
              <p className="inline-flex items-center gap-1 text-xs text-vida-moss mb-3">
                <Mail className="w-3 h-3" /> Health snapshot sent to practice
              </p>
            )}

            <div className="flex flex-wrap items-center gap-x-4 gap-y-2 mt-1">
              {apt.status === "confirmed" && (
                <button
                  onClick={() => downloadAppointmentICS(apt)}
                  className="inline-flex items-center gap-1 text-xs text-vida-moss hover:text-primary transition-colors"
                >
                  <CalendarPlus className="w-3 h-3" /> Add to Apple Calendar
                </button>
              )}
              {apt.status !== "cancelled" && apt.status !== "completed" && (
                <GoogleCalendarSync appointment={apt} />
              )}
              {apt.status !== "cancelled" && (
                <button
                  onClick={() => onCancel(apt.id)}
                  className="inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-destructive transition-colors"
                >
                  <X className="w-3 h-3" /> Cancel appointment
                </button>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}