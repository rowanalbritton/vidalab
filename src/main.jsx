import React from 'react'
import ReactDOM from 'react-dom/client'
import App from '@/App.jsx'
import '@/index.css'

const rootEl = document.getElementById('root');

try {
  ReactDOM.createRoot(rootEl).render(<App />);
  // Hide the CSS-only loading indicator after React paints its first frame
  requestAnimationFrame(() => {
    document.documentElement.classList.add('app-mounted');
  });
} catch (e) {
  console.error('Failed to render app:', e);
  document.documentElement.classList.add('app-mounted');
  rootEl.innerHTML = '<div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:#F9F8F5;font-family:Georgia,serif;color:#2E463E;padding:2rem;"><div style="max-width:500px;text-align:center;"><h2 style="font-size:1.5rem;margin-bottom:0.75rem;">Something went wrong</h2><p style="color:#5a655e;font-size:0.9rem;margin-bottom:1rem;">The app failed to render.</p><pre style="padding:1rem;background:#fff;border:1px solid #E8E5DF;border-radius:8px;font-size:0.75rem;text-align:left;overflow:auto;max-height:200px;color:#5a655e;">' + (e.message || String(e)) + '</pre><button onclick="location.reload()" style="margin-top:1.5rem;padding:0.75rem 1.5rem;border-radius:9999px;background:#2E463E;color:#F9F8F5;border:none;font-size:0.875rem;cursor:pointer;">Reload page</button></div></div>';
}