import { createClientFromRequest } from 'npm:@base44/sdk@0.8.44';
import { generateInsight } from '../../shared/insights.ts';
import { initSupabase } from "../../shared/supabaseServer.ts";

// Mobile Check-in — accepts check-in data, generates the educational insight,
// saves the record, and returns the saved check-in with insight in one call.
// This mirrors the web app's DailyCheckinForm + insight flow.
export default async function(req) {
  try {
    const base44 = createClientFromRequest(req);
    const { body, user, entities } = await initSupabase(req);
    if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 });

    // Validate required fields
    const { checkin_date, energy, mood } = body;
    if (!checkin_date || energy == null || !mood) {
      return Response.json(
        { error: 'Missing required fields: checkin_date, energy, mood' },
        { status: 400 }
      );
    }

    // Build the check-in record
    const checkinData = {
      checkin_date,
      energy: Number(energy),
      sleep_hours: body.sleep_hours != null ? Number(body.sleep_hours) : undefined,
      sleep_quality: body.sleep_quality != null ? Number(body.sleep_quality) : undefined,
      mood,
      pain_level: body.pain_level != null ? Number(body.pain_level) : 0,
      cycle_phase: body.cycle_phase || 'not_tracking',
      symptoms: Array.isArray(body.symptoms) ? body.symptoms : [],
      practices: Array.isArray(body.practices) ? body.practices : [],
      notes: body.notes || '',
    };

    // Generate the educational insight (rule-based, deterministic)
    checkinData.insight = generateInsight(checkinData);

    // Save to the shared database — visible on web and app
    const saved = await entities.DailyCheckin.create(checkinData);

    return Response.json({
      success: true,
      checkin: saved,
      insight: saved.insight,
    });
  } catch (error) {
    console.error('mobile-checkin error:', error?.message || error);
    return Response.json({ error: error?.message || 'Internal error' }, { status: 500 });
  }
}