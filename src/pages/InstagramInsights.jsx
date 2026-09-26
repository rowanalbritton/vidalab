import React, { useState, useEffect, useCallback } from "react";
import { base44 } from "@/api/base44Client";
import { useAuth } from "@/lib/AuthContext";
import SentimentCard from "@/components/instagram/SentimentCard";
import EngagementCard from "@/components/instagram/EngagementCard";
import FeedbackCard from "@/components/instagram/FeedbackCard";
import { RefreshCw, Lock, AlertCircle, Instagram } from "lucide-react";
import Loader from "@/components/Loader";

export default function InstagramInsights() {
  const { user } = useAuth();
  const isAdmin = user?.role === "admin";
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await base44.functions.invoke("instagram-insights", {});
      setData(res.data);
    } catch (err) {
      setError(err?.response?.data?.error || "Failed to load Instagram insights");
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    if (isAdmin) load();
    else setLoading(false);
  }, [isAdmin, load]);

  if (!isAdmin) {
    return (
      <main className="max-w-2xl mx-auto px-5 py-20 text-center">
        <Lock className="w-10 h-10 text-muted-foreground mx-auto mb-4" strokeWidth={1} />
        <h1 className="font-heading text-2xl text-primary mb-2">Admin only</h1>
        <p className="text-muted-foreground">Instagram insights are available to admins.</p>
      </main>
    );
  }

  if (loading) {
    return (
      <main className="flex justify-center py-24">
        <Loader />
      </main>
    );
  }

  if (error) {
    return (
      <main className="max-w-2xl mx-auto px-5 py-20 text-center">
        <AlertCircle className="w-10 h-10 text-muted-foreground mx-auto mb-4" strokeWidth={1} />
        <h1 className="font-heading text-2xl text-primary mb-2">Couldn't load insights</h1>
        <p className="text-muted-foreground mb-6">{error}</p>
        <button onClick={load} className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full bg-primary text-primary-foreground text-sm font-medium">
          <RefreshCw className="w-4 h-4" /> Try again
        </button>
      </main>
    );
  }

  if (!data) return null;

  return (
    <main className="max-w-5xl mx-auto px-5 sm:px-8 py-10">
      <div className="flex items-start justify-between mb-10 flex-wrap gap-4">
        <div>
          <span className="text-xs uppercase tracking-widest text-muted-foreground flex items-center gap-1.5">
            <Instagram className="w-3.5 h-3.5" /> Instagram Insights
          </span>
          <h1 className="font-heading text-4xl text-primary mt-1">@{data.username}</h1>
          <p className="text-muted-foreground mt-2 max-w-xl">
            {data.postCount} posts analyzed · {data.totalComments} comments reviewed
          </p>
        </div>
        <button
          onClick={load}
          className="inline-flex items-center gap-2 px-4 py-2.5 rounded-full border border-border text-sm font-medium text-primary hover:bg-muted transition-colors"
        >
          <RefreshCw className="w-4 h-4" /> Refresh
        </button>
      </div>

      <div className="grid gap-6">
        <SentimentCard sentiment={data.analysis?.sentiment} />
        <EngagementCard engagement={data.analysis?.engagement} />
        <FeedbackCard feedback={data.analysis?.feedback} />
      </div>
    </main>
  );
}