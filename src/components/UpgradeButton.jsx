import React, { useState } from "react";
import { useAuth } from "@/lib/AuthContext";
import { base44 } from "@/api/base44Client";
import { Loader2, Sparkles } from "lucide-react";

export default function UpgradeButton({
  productId = "vida_plus_monthly",
  children,
  className = "",
}) {
  const { isAuthenticated, navigateToLogin } = useAuth();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleUpgrade = async () => {
    if (!isAuthenticated) {
      navigateToLogin();
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const res = await base44.functions.invoke("create-checkout", { productId });
      const redirectUrl = res.data?.redirectUrl;
      if (redirectUrl) {
        window.location.href = redirectUrl;
      } else {
        setError("Could not start checkout. Please try again.");
        setLoading(false);
      }
    } catch (e) {
      setError(e?.response?.data?.error || "Could not start checkout. Please try again.");
      setLoading(false);
    }
  };

  return (
    <>
      <button
        onClick={handleUpgrade}
        disabled={loading}
        className={className}
      >
        {loading ? (
          <><Loader2 className="w-4 h-4 mr-2 animate-spin" /> Starting checkout…</>
        ) : (
          children || <><Sparkles className="w-4 h-4" /> Get Vida+</>
        )}
      </button>
      {error && <p className="text-sm text-destructive mt-2">{error}</p>}
    </>
  );
}