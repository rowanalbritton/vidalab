import React, { createContext, useState, useContext, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabaseClient';

const AuthContext = createContext();

/**
 * Auth state for the site, backed entirely by Supabase Auth.
 *
 * This is the same account system the iOS app signs into, which is the whole
 * point: a member who registers on the phone can sign in here and see their
 * own data.
 *
 * Previously this module imported the Base44 client and gated the first
 * session check on `appParams.token`. That token is a Base44 artefact, so on
 * any normal visit it was absent and a signed-in member was reported as
 * anonymous until `onAuthStateChange` happened to fire. The session is now read
 * directly, and the listener only keeps it up to date.
 */
export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoadingAuth, setIsLoadingAuth] = useState(true);
  const [authError, setAuthError] = useState(null);
  const [authChecked, setAuthChecked] = useState(false);

  /**
   * Reads the signed-in member, merging their profile row over the auth
   * record. Kept in this shape because callers across the site already read
   * these field names.
   */
  const loadUser = useCallback(async (session) => {
    if (!session?.user) {
      setUser(null);
      setIsAuthenticated(false);
      return;
    }

    // A missing or unreadable profile must not sign the member out. They are
    // authenticated either way, and the profile only decorates that.
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', session.user.id)
      .maybeSingle();

    if (error) console.warn('Profile load failed; continuing with auth record only.', error);

    setUser({
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
    });
    setIsAuthenticated(true);
  }, []);

  const checkUserAuth = useCallback(async () => {
    setIsLoadingAuth(true);
    setAuthError(null);
    try {
      const { data: { session }, error } = await supabase.auth.getSession();
      if (error) throw error;
      await loadUser(session);
    } catch (error) {
      console.error('User auth check failed:', error);
      setUser(null);
      setIsAuthenticated(false);
      setAuthError({ type: 'unknown', message: error.message || 'Could not check your session.' });
    } finally {
      setIsLoadingAuth(false);
      setAuthChecked(true);
    }
  }, [loadUser]);

  useEffect(() => {
    checkUserAuth();

    // Supabase restores the session from storage asynchronously, so
    // INITIAL_SESSION can arrive after the read above. Handling both means the
    // first paint is correct whichever wins.
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (event === 'SIGNED_OUT') {
        setUser(null);
        setIsAuthenticated(false);
        setAuthChecked(true);
        setIsLoadingAuth(false);
        return;
      }

      if (session) {
        await loadUser(session);
        setAuthChecked(true);
        setIsLoadingAuth(false);
      }
    });

    return () => subscription.unsubscribe();
  }, [checkUserAuth, loadUser]);

  const logout = async (shouldRedirect = true) => {
    await supabase.auth.signOut();
    setUser(null);
    setIsAuthenticated(false);
    if (shouldRedirect) window.location.href = '/';
  };

  const navigateToLogin = () => {
    const returnTo = encodeURIComponent(window.location.href);
    window.location.href = `/login?returnTo=${returnTo}`;
  };

  return (
    <AuthContext.Provider value={{
      user,
      isAuthenticated,
      isLoadingAuth,
      // Base44's app-settings call is gone. Kept as a settled `false` so the
      // components that still wait on it render instead of spinning forever.
      isLoadingPublicSettings: false,
      appPublicSettings: null,
      authError,
      authChecked,
      logout,
      navigateToLogin,
      checkUserAuth,
      // Older callers used this to re-check app state; auth is all that is
      // left to re-check.
      checkAppState: checkUserAuth,
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
