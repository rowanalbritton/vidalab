// Generates an .ics (iCalendar) file for a doctor appointment so members can
// import it into Apple Calendar (or any calendar app) with full event details.

function formatICSDateTime(dateStr, timeStr) {
  const date = (dateStr || "").replace(/-/g, "");
  const time = (timeStr || "09:00").replace(":", "").padEnd(4, "0");
  return `${date}T${time}00`;
}

function endTimePlusOneHour(timeStr) {
  const [h, m] = (timeStr || "09:00").split(":").map(Number);
  const endH = (h + 1) % 24;
  return `${String(endH).padStart(2, "0")}${String(m || 0).padStart(2, "0")}00`;
}

function escapeICS(text) {
  if (!text) return "";
  return String(text)
    .replace(/\\/g, "\\\\")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
    .replace(/\r?\n/g, "\\n");
}

export function generateAppointmentICS(appointment) {
  const dateOnly = (appointment.appointment_date || "").replace(/-/g, "");
  const dtStart = formatICSDateTime(appointment.appointment_date, appointment.appointment_time);
  const dtEnd = `${dateOnly}T${endTimePlusOneHour(appointment.appointment_time)}`;

  const summary = `Appointment — ${appointment.practice_name || appointment.doctor_name || "Doctor"}`;
  const location = appointment.practice_name || appointment.doctor_name || "";

  const descParts = [
    appointment.doctor_name ? `Doctor: ${appointment.doctor_name}` : "",
    appointment.specialty ? `Specialty: ${appointment.specialty}` : "",
    appointment.reason ? `Reason for visit: ${appointment.reason}` : "",
    appointment.notes ? `Notes: ${appointment.notes}` : "",
    "— Added via Vida Lab",
  ].filter(Boolean);

  const uid = `${appointment.id}@vidalab.base44.app`;
  const dtstamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");

  return [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Vida Lab//Appointment//EN",
    "CALSCALE:GREGORIAN",
    "BEGIN:VEVENT",
    `UID:${uid}`,
    `DTSTAMP:${dtstamp}`,
    `DTSTART:${dtStart}`,
    `DTEND:${dtEnd}`,
    `SUMMARY:${escapeICS(summary)}`,
    `LOCATION:${escapeICS(location)}`,
    `DESCRIPTION:${escapeICS(descParts.join("\n"))}`,
    "END:VEVENT",
    "END:VCALENDAR",
  ].join("\r\n");
}

export function downloadAppointmentICS(appointment) {
  const ics = generateAppointmentICS(appointment);
  const blob = new Blob([ics], { type: "text/calendar;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = `vida-appointment-${appointment.appointment_date || "event"}.ics`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

// Builds a Google Calendar "add event" URL with all appointment details pre-filled.
// Opens Google Calendar in the browser — if the user is signed in, they just click Save.
export function googleCalendarUrl(appointment) {
  const dateOnly = (appointment.appointment_date || "").replace(/-/g, "");
  const timeStr = appointment.appointment_time || "09:00";
  const [h, m] = timeStr.split(":").map(Number);
  const startTime = `${String(h || 9).padStart(2, "0")}${String(m || 0).padStart(2, "0")}00`;
  const dtStart = `${dateOnly}T${startTime}`;
  const endH = String((h + 1) % 24).padStart(2, "0");
  const dtEnd = `${dateOnly}T${endH}${String(m || 0).padStart(2, "0")}00`;

  const text = encodeURIComponent(
    `Appointment — ${appointment.practice_name || appointment.doctor_name || "Doctor"}`
  );
  const details = encodeURIComponent(
    [
      appointment.doctor_name ? `Doctor: ${appointment.doctor_name}` : "",
      appointment.specialty ? `Specialty: ${appointment.specialty}` : "",
      appointment.reason ? `Reason for visit: ${appointment.reason}` : "",
      appointment.notes ? `Notes: ${appointment.notes}` : "",
      "— Added via Vida Lab",
    ]
      .filter(Boolean)
      .join("\n")
  );
  const location = encodeURIComponent(appointment.practice_name || appointment.doctor_name || "");

  return `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${text}&dates=${dtStart}/${dtEnd}&details=${details}&location=${location}`;
}