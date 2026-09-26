import { createClientFromRequest } from 'npm:@base44/sdk@0.8.48';
import { initSupabase } from "../../shared/supabaseServer.ts";

const CONTACTS_CONNECTOR_ID = "6ab2084c0df62ea6055b6758";

export default async function (req: Request) {
  const base44 = createClientFromRequest(req);
  const { user, entities } = await initSupabase(req);
  if (!user) return Response.json({ error: "Unauthorized" }, { status: 401 });

  let accessToken: string;
  try {
    const conn = await base44.asServiceRole.connectors.getCurrentAppUserConnection(CONTACTS_CONNECTOR_ID);
    accessToken = conn.accessToken;
  } catch (e) {
    return Response.json({ error: "Google Contacts not connected" }, { status: 403 });
  }

  // Get doctors from the user's appointments
  const appointments = await entities.Appointment.list("-appointment_date", 200);
  const doctorIds = [...new Set(appointments.map((a: any) => a.doctor_id).filter(Boolean))];

  if (doctorIds.length === 0) {
    return Response.json({ error: "No saved doctors to sync. Book an appointment first." }, { status: 400 });
  }

  // Fetch full doctor records
  const doctors: any[] = [];
  for (const id of doctorIds) {
    try {
      const doc = await entities.Doctor.get(id);
      doctors.push(doc);
    } catch (e) { /* skip */ }
  }

  if (doctors.length === 0) {
    return Response.json({ error: "No doctor records found." }, { status: 400 });
  }

  const headers = { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" };
  let created = 0;

  for (const doc of doctors) {
    const contact: any = {
      names: [{ displayName: `Dr. ${doc.practice_name || doc.specialty}` }],
      organizations: [{ title: doc.specialty, name: doc.practice_name }],
    };
    if (doc.phone) contact.phoneNumbers = [{ value: doc.phone, type: "work" }];
    if (doc.email) contact.emailAddresses = [{ value: doc.email, type: "work" }];
    if (doc.website) contact.urls = [{ value: doc.website, type: "work" }];
    if (doc.address || doc.city) {
      contact.addresses = [{
        formattedValue: [doc.address, doc.city, doc.state, doc.zip_code].filter(Boolean).join(", "),
        type: "work",
      }];
    }

    const res = await fetch("https://people.googleapis.com/v1/people:createContact", {
      method: "POST",
      headers,
      body: JSON.stringify(contact),
    });
    if (res.ok) created++;
  }

  return Response.json({ created, total: doctors.length });
}