import React, { useState } from "react";
import { base44 } from "@/api/base44Client";
import { Loader2, Link2, Check, AlertCircle } from "lucide-react";

/**
 * Reusable button for Google connector integrations (APP_USER mode).
 * Handles the connect → invoke → success/error flow automatically.
 *
 * Props:
 * - connectorId: workspace connector ID
 * - functionName: backend function to invoke
 * - args: arguments to pass to the function
 * - label: button text (idle state)
 * - connectLabel: button text (needs-connect state)
 * - successLabel: text shown on success
 * - successUrlKey: key in response data containing a URL to open (optional)
 * - icon: lucide icon component
 */
export default function GoogleSyncButton({
  connectorId,
  functionName,
  args = {},
  label,
  connectLabel,
  successLabel,
  successUrlKey,
  icon: Icon,
}) {
  const [status, setStatus] = useState("idle"); // idle | loading | success | needsConnect | error
  const [result, setResult] = useState(null);
  const [errorMsg, setErrorMsg] = useState("");

  const handleSync = async () => {
    setStatus("loading");
    setErrorMsg("");
    try {
      const res = await base44.functions.invoke(functionName, args);
      setResult(res.data);
      setStatus("success");
    } catch (err) {
      const msg = err?.response?.data?.error || err?.message || "";
      if (msg.includes("not connected") || err?.response?.status === 403) {
        setStatus("needsConnect");
      } else {
        setErrorMsg(msg);
        setStatus("error");
      }
    }
  };

  const handleConnect = async () => {
    setStatus("loading");
    try {
      const url = await base44.connectors.connectAppUser(connectorId);
      const popup = window.open(url, "_blank");
      const timer = setInterval(() => {
        if (!popup || popup.closed) {
          clearInterval(timer);
          handleSync();
        }
      }, 600);
    } catch (e) {
      setStatus("error");
    }
  };

  const btnClass =
    "inline-flex items-center gap-2 px-5 py-2.5 rounded-full text-sm font-medium transition-colors disabled:opacity-50";
  const btnStyle = { background: "transparent", color: "var(--forest)", border: "1px solid var(--line)" };

  if (status === "success") {
    return (
      <div className="inline-flex items-center gap-2 text-sm" style={{ color: "var(--moss)" }}>
        <Check className="w-4 h-4" /> {successLabel}
        {successUrlKey && result?.[successUrlKey] && (
          <a
            href={result[successUrlKey]}
            target="_blank"
            rel="noopener noreferrer"
            className="underline"
            style={{ color: "var(--moss)" }}
          >
            Open
          </a>
        )}
      </div>
    );
  }

  if (status === "needsConnect") {
    return (
      <button onClick={handleConnect} className={btnClass} style={btnStyle}>
        <Link2 className="w-4 h-4" /> {connectLabel}
      </button>
    );
  }

  if (status === "error") {
    return (
      <div className="inline-flex items-center gap-2 text-sm" style={{ color: "var(--clay)" }}>
        <AlertCircle className="w-4 h-4" />
        <span>{errorMsg || "Something went wrong"}</span>
        <button onClick={() => setStatus("idle")} className="underline text-xs ml-1">Retry</button>
      </div>
    );
  }

  return (
    <button onClick={handleSync} disabled={status === "loading"} className={btnClass} style={btnStyle}>
      {status === "loading" ? <Loader2 className="w-4 h-4 animate-spin" /> : Icon ? <Icon className="w-4 h-4" /> : null}
      {label}
    </button>
  );
}