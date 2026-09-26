import React from "react";
import { APP_STORE_URL, APP_STORE_COMING_SOON_LABEL } from "@/lib/appStoreConfig";

// Links to the App Store when APP_STORE_URL is set; otherwise renders the same
// button, dimmed and non-clickable, with the "Coming soon" label.
export default function AppStoreButton({ className = "button", icon = null, children }) {
  if (APP_STORE_URL) {
    return (
      <a className={className} href={APP_STORE_URL} target="_blank" rel="noopener noreferrer">
        {icon}{children}
      </a>
    );
  }

  return (
    <span
      className={className}
      role="link"
      aria-disabled="true"
      style={{ opacity: 0.55, cursor: "not-allowed", transform: "none" }}
    >
      {icon}{APP_STORE_COMING_SOON_LABEL}
    </span>
  );
}
