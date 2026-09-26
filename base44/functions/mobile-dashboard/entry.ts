import { createClientFromRequest } from 'npm:@base44/sdk@0.8.44';
import { initSupabase } from "../../shared/supabaseServer.ts";

// Mobile Dashboard — returns everything the iOS app home screen needs in one call.
// Reduces multiple API round-trips from the native app to a single request.
export default async function(req) {
  try {
    const base44 = createClientFromRequest(req);
    const { user, entities } = await initSupabase(req);
    if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 });

    // Fetch all user data in parallel for speed
    const [checkins, favorites, experiments, appointments, treatments] = await Promise.all([
      entities.DailyCheckin.filter({}, '-checkin_date', 30),
      entities.Favorite.filter({}, '-created_date', 500),
      entities.Experiment.filter({ status: 'active' }, '-created_date', 10),
      entities.Appointment.filter(
        { status: { $in: ['confirmed', 'requested'] } },
        'appointment_date', 10
      ),
      entities.Treatment.filter({ status: 'current' }, '-created_date', 20),
    ]);

    return Response.json({
      user: {
        id: user.id,
        email: user.email,
        full_name: user.full_name,
        role: user.role,
        membership: user.membership || null,
        has_vida_plus: user.membership === 'vida_plus',
      },
      latestCheckin: checkins[0] || null,
      recentCheckins: checkins,
      favorites: favorites.map(f => ({
        id: f.id,
        resource_id: f.resource_id,
        resource_title: f.resource_title,
        resource_category: f.resource_category,
      })),
      activeExperiments: experiments,
      upcomingAppointments: appointments,
      currentTreatments: treatments,
    });
  } catch (error) {
    console.error('mobile-dashboard error:', error?.message || error);
    return Response.json({ error: error?.message || 'Internal error' }, { status: 500 });
  }
}