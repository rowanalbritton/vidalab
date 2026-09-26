import React, { useState, useEffect, useRef } from "react";
import { Link, useNavigate } from "react-router-dom";
import { base44 } from "@/api/base44Client";
import { useAuth } from "@/lib/AuthContext";
import { Loader2, CheckCircle2 } from "lucide-react";

export default function ThankYou() {
  const [status, setStatus] = useState("confirming"); // confirming | activated | timeout
  const [retryCount, setRetryCount] = useState(0);
  const timerRef = useRef(null);
  const { checkUserAuth } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    let attempts = 0;
    const maxAttempts = 150; // 150 * 0.8s = 120s

    const stopPolling = () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };

    const activate = async () => {
      stopPolling();
      // Refresh AuthContext so gated pages see updated membership.
      // Wrapped in try-catch: checkUserAuth sets isLoadingAuth=true which can
      // briefly show a loading state — don't let that block the activated UI.
      try {
        await checkUserAuth();
      } catch (_) {}
      setStatus("activated");
    };

    const check = async () => {
      attempts++;
      try {
        const me = await base44.auth.me();

        // 1. Auth already shows vida_plus (webhook fired and auth refreshed)
        if (me?.membership === "vida_plus") {
          await activate();
          return;
        }

        // 2. Webhook already marked a purchase as paid — activate immediately.
        // The webhook grants membership server-side; no need to double-check via DB.
        try {
          const purchases = await base44.entities.Base44Purchase.list("-updated_date", 10);
          const paidVidaPlus = purchases?.find(
            (p) => p.productId === "vida_plus_monthly" && p.status === "paid"
          );
          if (paidVidaPlus) {
            await activate();
            return;
          }
        } catch (_) {}

        // 3. Fallback: call check-payment-status every ~2.4s (every 3rd attempt).
        // The function checks the Wix orders API for a verified paid order and
        // grants vida_plus server-side once payment is confirmed.
        if (attempts % 3 === 1) {
          try {
            const response = await base44.functions.invoke("check-payment-status", {});
            if (response?.data?.status === "paid") {
              await activate();
              return;
            }
          } catch (e) {
            // Function call failed — keep polling
          }
        }
      } catch (e) {
        // Not logged in or error — keep polling
      }
      if (attempts >= maxAttempts) {
        setStatus("timeout");
        stopPolling();
      }
    };

    check();
    timerRef.current = setInterval(check, 800);

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [retryCount]);

  // Auto-redirect to the member dashboard shortly after activation
  useEffect(() => {
    if (status === "activated") {
      const redirectTimer = setTimeout(() => navigate("/welcome"), 1200);
      return () => clearTimeout(redirectTimer);
    }
  }, [status, navigate]);

  return (
    <main className="min-h-[70vh] flex items-center justify-center px-5 py-16">
      <div className="max-w-lg text-center">
        {status === "confirming" && (
          <>
            <div className="w-16 h-16 rounded-full bg-accent/20 flex items-center justify-center mx-auto mb-6">
              <Loader2 className="w-7 h-7 text-primary animate-spin" strokeWidth={1.5} />
            </div>
            <h1 className="font-heading text-3xl text-primary mb-3">Confirming your payment…</h1>
            <p className="text-muted-foreground leading-relaxed">
              We're activating your Vida+ membership. This usually takes a few seconds.
              You'll be redirected automatically once it's ready.
            </p>
          </>
        )}

        {status === "activated" && (
          <>
            <div className="w-16 h-16 rounded-full bg-accent/20 flex items-center justify-center mx-auto mb-6">
              <CheckCircle2 className="w-7 h-7 text-primary" strokeWidth={1.5} />
            </div>
            <h1 className="font-heading text-3xl text-primary mb-3">Welcome to Vida+</h1>
            <p className="text-muted-foreground leading-relaxed">
              Your membership is active. Taking you to your dashboard…
            </p>
          </>
        )}

        {status === "timeout" && (
          <>
            <div className="w-16 h-16 rounded-full bg-accent/20 flex items-center justify-center mx-auto mb-6">
              <Loader2 className="w-7 h-7 text-primary" strokeWidth={1.5} />
            </div>
            <h1 className="font-heading text-3xl text-primary mb-3">Still confirming…</h1>
            <p className="text-muted-foreground leading-relaxed mb-8">
              Your payment is being processed. It can take a minute to fully activate.
              Try refreshing this page, or come back in a moment — your Vida+ access will be ready.
            </p>
            <div className="flex flex-col sm:flex-row gap-3 justify-center">
              <button
                onClick={() => {
                  setStatus("confirming");
                  setRetryCount((c) => c + 1);
                }}
                className="inline-flex items-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
              >
                <Loader2 className="w-4 h-4" /> Retry verification
              </button>
              <Link
                to="/"
                className="inline-flex items-center gap-2 px-6 py-3 rounded-full border border-primary/30 text-primary text-sm font-medium hover:bg-primary/5 transition-colors"
              >
                Back to Vida Lab
              </Link>
            </div>
          </>
        )}
      </div>
    </main>
  );
}