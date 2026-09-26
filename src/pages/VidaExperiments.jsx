import React, { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { base44 } from "@/api/base44Client";
import { useAuth } from "@/lib/AuthContext";
import MembershipGate from "@/components/MembershipGate";
import CreateExperimentForm from "@/components/experiments/CreateExperimentForm";
import ExperimentResults from "@/components/experiments/ExperimentResults";
import DailyAdherenceLog from "@/components/experiments/DailyAdherenceLog";
import {
  FlaskConical,
  Plus,
  ArrowLeft,
  CheckCircle2,
  Circle,
  Play,
} from "lucide-react";
import Loader from "@/components/Loader";

export default function VidaExperiments() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";
  const [experiments, setExperiments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [selected, setSelected] = useState(null);
  const [logs, setLogs] = useState([]);

  const loadExperiments = async () => {
    try {
      const list = await base44.entities.Experiment.list("-created_date", 50);
      setExperiments(list);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!isVidaPlus) {
      setLoading(false);
      return;
    }
    loadExperiments();
  }, [isVidaPlus]);

  useEffect(() => {
    if (!selected) {
      setLogs([]);
      return;
    }
    base44.entities.ExperimentLog.filter({ experiment_id: selected.id }, "-log_date", 200)
      .then(setLogs)
      .catch(() => {});
  }, [selected]);

  const onLogged = () => {
    if (!selected) return;
    base44.entities.ExperimentLog.filter({ experiment_id: selected.id }, "-log_date", 200)
      .then(setLogs)
      .catch(() => {});
  };

  const handleEndExperiment = async () => {
    try {
      await base44.entities.Experiment.update(selected.id, { status: "completed" });
      setSelected({ ...selected, status: "completed" });
      loadExperiments();
    } catch (e) {
      console.error(e);
    }
  };

  if (!isVidaPlus) {
    return (
      <MembershipGate title="Vida Experiments is a Vida+ feature">
        Stop guessing if that supplement or diet works. Vida Experiments lets you run structured n=1
        self-experiments, track adherence, and see — with confidence — what actually moves the needle.
      </MembershipGate>
    );
  }

  if (loading) {
    return (
      <div className="flex justify-center py-24">
        <Loader />
      </div>
    );
  }

  // ===== Detail view =====
  if (selected) {
    const isActive = selected.status === "active";
    const startDate = new Date((selected.start_date || "").slice(0, 10) + "T00:00:00");
    const today = new Date();
    const dayNum = Math.floor((today - startDate) / (1000 * 60 * 60 * 24)) + 1;
    const progressPct = Math.min(100, (dayNum / (selected.duration_days || 21)) * 100);
    const adherentCount = logs.filter((l) => l.adhered).length;
    const adherenceRate = logs.length > 0 ? Math.round((adherentCount / logs.length) * 100) : 0;

    return (
      <main className="max-w-3xl mx-auto px-5 sm:px-8 py-10">
        <button
          onClick={() => setSelected(null)}
          className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" /> All experiments
        </button>

        <span className="text-xs uppercase tracking-widest text-muted-foreground">
          {isActive ? "Active experiment" : "Completed experiment"} · Vida+
        </span>
        <h1 className="font-heading text-3xl text-primary mt-1">{selected.title}</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">{selected.intervention}</p>

        {/* Hypothesis */}
        <div className="rounded-2xl bg-vida-sage/10 border border-vida-sage/30 p-5 mt-5">
          <p className="text-xs uppercase tracking-widest text-vida-moss mb-1">Hypothesis</p>
          <p className="text-sm text-muted-foreground leading-relaxed">{selected.hypothesis}</p>
        </div>

        {isActive && (
          <>
            {/* Progress */}
            <div className="rounded-2xl bg-card border border-border p-6 mt-5">
              <div className="flex items-center justify-between mb-3">
                <p className="text-sm font-medium text-primary">Progress</p>
                <p className="text-sm text-muted-foreground">
                  Day {Math.min(dayNum, selected.duration_days)} of {selected.duration_days}
                </p>
              </div>
              <div className="h-2 rounded-full bg-muted overflow-hidden mb-4">
                <div
                  className="h-full bg-vida-moss rounded-full transition-all"
                  style={{ width: `${progressPct}%` }}
                />
              </div>
              <div className="flex gap-6">
                <div>
                  <p className="text-xs uppercase tracking-widest text-muted-foreground">Days logged</p>
                  <p className="font-heading text-xl text-primary">{logs.length}</p>
                </div>
                <div>
                  <p className="text-xs uppercase tracking-widest text-muted-foreground">Adherence</p>
                  <p className="font-heading text-xl text-primary">{adherenceRate}%</p>
                </div>
              </div>
            </div>

            {/* Daily log */}
            <div className="mt-5">
              <DailyAdherenceLog experiment={selected} logs={logs} onLogged={onLogged} />
            </div>

            {/* Recent logs */}
            {logs.length > 0 && (
              <div className="mt-5">
                <h3 className="font-heading text-lg text-primary mb-3">Recent logs</h3>
                <div className="space-y-2">
                  {logs.slice(0, 7).map((log) => (
                    <div key={log.id} className="flex items-start gap-3 rounded-xl bg-card border border-border p-3">
                      {log.adhered ? (
                        <CheckCircle2 className="w-5 h-5 text-vida-moss shrink-0 mt-0.5" strokeWidth={1.5} />
                      ) : (
                        <Circle className="w-5 h-5 text-vida-taupe shrink-0 mt-0.5" strokeWidth={1.5} />
                      )}
                      <div>
                        <p className="text-sm text-foreground">
                          {new Date((log.log_date || "").slice(0, 10) + "T00:00:00").toLocaleDateString(undefined, {
                            weekday: "short",
                            month: "short",
                            day: "numeric",
                          })}
                        </p>
                        {log.notes && <p className="text-xs text-muted-foreground mt-0.5">{log.notes}</p>}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* End experiment */}
            <div className="mt-6 text-center">
              <button
                onClick={handleEndExperiment}
                className="inline-flex items-center gap-2 px-5 py-2.5 rounded-full border border-border text-muted-foreground text-sm hover:border-primary hover:text-primary transition-colors"
              >
                <Play className="w-4 h-4" /> End & analyze experiment
              </button>
            </div>
          </>
        )}

        {/* Results */}
        {selected.status === "completed" && (
          <div className="mt-5">
            <ExperimentResults experiment={selected} onResults={loadExperiments} />
          </div>
        )}
      </main>
    );
  }

  // ===== List view =====
  const active = experiments.filter((e) => e.status === "active");
  const completed = experiments.filter((e) => e.status === "completed");

  return (
    <main className="max-w-3xl mx-auto px-5 sm:px-8 py-10">
      <div className="mb-8">
        <Link
          to="/daily-signals"
          className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary transition-colors mb-4"
        >
          <ArrowLeft className="w-4 h-4" /> Back to Daily Signals
        </Link>
        <span className="text-xs uppercase tracking-widest text-muted-foreground">Vida+ Experiments</span>
        <h1 className="font-heading text-4xl text-primary mt-1">Vida Experiments</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">
          Stop guessing. Run structured n=1 self-experiments on supplements, diets, and lifestyle changes —
          and see what actually moves the needle.
        </p>
      </div>

      {showCreate ? (
        <CreateExperimentForm
          onCreated={(exp) => {
            setShowCreate(false);
            loadExperiments();
            setSelected(exp);
          }}
        />
      ) : (
        <>
          <button
            onClick={() => setShowCreate(true)}
            className="w-full mb-6 inline-flex items-center justify-center gap-2 px-6 py-3 rounded-full bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <Plus className="w-4 h-4" /> Start new experiment
          </button>

          {experiments.length === 0 ? (
            <div className="text-center py-16 rounded-2xl border border-dashed border-border">
              <FlaskConical className="w-10 h-10 text-muted-foreground mx-auto mb-4" strokeWidth={1.5} />
              <p className="text-muted-foreground">No experiments yet. Start your first one above.</p>
            </div>
          ) : (
            <div className="space-y-6">
              {active.length > 0 && (
                <div>
                  <h2 className="font-heading text-xl text-primary mb-3">Active</h2>
                  <div className="space-y-3">
                    {active.map((exp) => (
                      <button
                        key={exp.id}
                        onClick={() => setSelected(exp)}
                        className="w-full text-left rounded-2xl bg-card border border-border p-5 hover:border-primary/40 transition-colors"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <h3 className="font-heading text-lg text-primary">{exp.title}</h3>
                            <p className="text-sm text-muted-foreground mt-1">{exp.intervention}</p>
                          </div>
                          <span className="inline-flex items-center gap-1.5 rounded-full bg-vida-moss/15 px-2.5 py-1 text-xs font-medium text-vida-moss shrink-0">
                            Active
                          </span>
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {completed.length > 0 && (
                <div>
                  <h2 className="font-heading text-xl text-primary mb-3">Completed</h2>
                  <div className="space-y-3">
                    {completed.map((exp) => (
                      <button
                        key={exp.id}
                        onClick={() => setSelected(exp)}
                        className="w-full text-left rounded-2xl bg-card border border-border p-5 hover:border-primary/40 transition-colors"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <h3 className="font-heading text-lg text-primary">{exp.title}</h3>
                            <p className="text-sm text-muted-foreground mt-1">{exp.intervention}</p>
                          </div>
                          <span className="inline-flex items-center gap-1.5 rounded-full bg-muted px-2.5 py-1 text-xs font-medium text-muted-foreground shrink-0">
                            Completed
                          </span>
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </>
      )}
    </main>
  );
}