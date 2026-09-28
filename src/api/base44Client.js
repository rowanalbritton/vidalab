import { createClient } from '@base44/sdk';
import { appParams } from '@/lib/app-params';
import { supabase } from '@/lib/supabaseClient';
import { SUPABASE_FUNCTIONS_LIVE } from '@/lib/supabaseConfig';
import * as supaEntities from '@/lib/supabase/entities';

const { appId, token, functionsVersion, appBaseUrl } = appParams;

let base44Client;
try {
  base44Client = createClient({
    appId,
    token,
    functionsVersion,
    serverUrl: '',
    appBaseUrl
  });
} catch (e) {
  console.error('Failed to create base44 client:', e);
  base44Client = {
    app: { getPublicSettings: async () => null },
    functions: { invoke: async () => { throw new Error('Base44 client not initialized'); } },
    users: { inviteUser: async () => { throw new Error('Base44 client not initialized'); } },
    analytics: { track: () => {} },
  };
}

// ===== APP PROXY: no longer using Base44 app settings =====
base44Client.app = { getPublicSettings: async () => null };

// ===== ENTITY PROXY: all base44.entities.X calls go to Supabase =====
base44Client.entities = supaEntities;

// ===== FUNCTIONS PROXY =====
// Functions ported to Supabase run there once SUPABASE_FUNCTIONS_LIVE is on.
// The rest (the Google and Instagram connectors) stay on Base44, with the
// Supabase token attached so they can identify the member.
const SUPABASE_FUNCTIONS = new Set([
  'appointment-concierge',
  'body-weather-forecast',
  'check-payment-status',
  'create-checkout',
  'experiment-results',
  'flag-community-content',
  'newsletter-signup',
  'send-appointment-snapshot',
  'unsubscribe',
  'vida-differential',
]);

// Base44's client throws on a failed call and returns { data } otherwise, so
// the Supabase route does the same: pages keep reading res.data, and catch
// blocks can still read err.response.data like they would from Base44.
async function invokeSupabaseFunction(name, args) {
  const { data, error } = await supabase.functions.invoke(name, { body: args });
  if (!error) return { data };

  let body = null;
  const response = error.context;
  if (response && typeof response.json === 'function') {
    try { body = await response.json(); } catch { body = null; }
  }
  const failure = new Error(body?.error || error.message || `${name} failed`);
  failure.response = { status: response?.status, data: body };
  throw failure;
}

const _originalInvoke = base44Client.functions.invoke;
base44Client.functions.invoke = async (name, args = {}) => {
  if (SUPABASE_FUNCTIONS_LIVE && SUPABASE_FUNCTIONS.has(name)) {
    return invokeSupabaseFunction(name, args);
  }
  const { data: { session } } = await supabase.auth.getSession();
  const token = session?.access_token;
  return _originalInvoke(name, { ...args, _supabaseToken: token });
};

// ===== AUTH PROXY: all base44.auth.X calls go to Supabase Auth =====
base44Client.auth = {
  async me() {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session?.user) throw { status: 401, message: 'Not authenticated' };
    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', session.user.id)
      .maybeSingle();
    return {
      id: session.user.id,
      email: session.user.email,
      full_name: profile?.full_name || session.user.user_metadata?.full_name || '',
      role: profile?.role || 'user',
      membership: profile?.membership || null,
      gender: profile?.gender || null,
      health_concerns: profile?.health_concerns || [],
      hasVidaPlus: profile?.membership === 'vida_plus',
      reminder_enabled: profile?.reminder_enabled ?? true,
      reminder_time: profile?.reminder_time || '20:00',
      content_updates: profile?.content_updates ?? true,
      cycle_tracking_enabled: profile?.cycle_tracking_enabled ?? true,
    };
  },

  async updateMe(data) {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session?.user) throw new Error('Not authenticated');
    const updateData = { ...data };
    delete updateData.id;
    delete updateData.email;
    delete updateData.hasVidaPlus;
    // Use upsert so a profile is created if it doesn't exist yet
    // (no DB trigger auto-creates profiles on signup)
    const { data: profile, error } = await supabase
      .from('profiles')
      .upsert({ id: session.user.id, email: session.user.email, ...updateData })
      .select()
      .maybeSingle();
    if (error) throw error;
    return {
      id: session.user.id,
      email: session.user.email,
      full_name: profile?.full_name || '',
      role: profile?.role || 'user',
      membership: profile?.membership || null,
      gender: profile?.gender || null,
      health_concerns: profile?.health_concerns || [],
      hasVidaPlus: profile?.membership === 'vida_plus',
    };
  },

  async isAuthenticated() {
    const { data: { session } } = await supabase.auth.getSession();
    return !!session;
  },

  async logout(redirectUrl) {
    await supabase.auth.signOut();
    if (redirectUrl) window.location.href = redirectUrl;
  },

  redirectToLogin(nextUrl) {
    const loginUrl = '/login' + (nextUrl ? '?returnTo=' + encodeURIComponent(nextUrl) : '');
    window.location.href = loginUrl;
  },
};

export const base44 = base44Client;