import { getAccessToken } from '@base44/sdk';

const isNode = typeof window === 'undefined';

const isClearAccessTokenRequested = () => {
	try {
		return !isNode && new URLSearchParams(window.location.search).get("clear_access_token") === 'true';
	} catch {
		return false;
	}
};

const clearStoredAccessToken = () => {
	try {
		window.localStorage.removeItem('base44_access_token');
		window.localStorage.removeItem('token');
	} catch {
		// localStorage may be unavailable in restricted environments
	}
};

const getAppParams = () => {
	if (isClearAccessTokenRequested()) {
		clearStoredAccessToken();
	}
	let token = null;
	try {
		token = getAccessToken();
	} catch {
		// getAccessToken may fail in restricted environments — continue without token
	}
	// Auth is now handled by Supabase. The AuthContext checks appParams.token
	// to decide whether to call checkUserAuth(). Since Supabase sessions are
	// managed independently, always provide a truthy token so the auth check
	// runs — base44.auth.me() is proxied to Supabase in base44Client.js.
	if (!token) token = 'supabase-auth';
	return {
		appId: import.meta.env.VITE_BASE44_APP_ID,
		token,
		functionsVersion: import.meta.env.VITE_BASE44_FUNCTIONS_VERSION,
		appBaseUrl: import.meta.env.VITE_BASE44_APP_BASE_URL,
	};
};


export const appParams = {
	...getAppParams()
};