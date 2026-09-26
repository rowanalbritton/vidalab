import React, { useState, useEffect, useMemo, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { base44 } from "@/api/base44Client";
import { labelSymptom, labelMood } from "@/lib/insights";
import { X, ChevronRight, Sparkles, Heart } from "lucide-react";

const PRACTICE_LABELS = {
  meditation: "Meditation",
  gentle_exercise: "Gentle exercise",
  anti_inflammatory_meal: "Anti-inflammatory meals",
  supplement: "Supplements",
  breathing_exercise: "Breathing exercises",
  nature_time: "Time in nature",
  sleep_hygiene: "Sleep hygiene",
  hydration: "Hydration",
  gratitude: "Gratitude",
  stretching: "Stretching",
};

const FOREST_SLIDES = new Set(["intro", "energy", "mood", "practices", "note"]);

function CountUp({ value, duration = 1200, decimals = 0, suffix = "" }) {
  const [display, setDisplay] = useState(0);
  useEffect(() => {
    const start = performance.now();
    let raf;
    const tick = (now) => {
      const progress = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      setDisplay(value * eased);
      if (progress < 1) raf = requestAnimationFrame(tick);
      else setDisplay(value);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [value, duration]);
  return (
    <>
      {display.toFixed(decimals)}
      {suffix}
    </>
  );
}

function formatDate(d) {
  return new Date(d.slice(0, 10) + "T00:00:00").toLocaleDateString(undefined, {
    month: "short",
    day: "numeric",
  });
}

function computeRewindStats(checkins) {
  const now = new Date();
  const cutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const monthly = checkins
    .filter((c) => new Date(c.checkin_date.slice(0, 10) + "T00:00:00") >= cutoff)
    .sort((a, b) => (a.checkin_date < b.checkin_date ? -1 : 1));

  if (monthly.length === 0) return null;

  const checkinCount = monthly.length;
  const daysTrackedPct = Math.round((checkinCount / 30) * 100);

  // Streak
  let maxStreak = 0,
    currentStreak = 0;
  let lastDate = null;
  monthly.forEach((c) => {
    const d = new Date(c.checkin_date.slice(0, 10) + "T00:00:00");
    if (lastDate) {
      const diff = Math.round((d - lastDate) / (1000 * 60 * 60 * 24));
      currentStreak = diff === 1 ? currentStreak + 1 : 1;
    } else {
      currentStreak = 1;
    }
    maxStreak = Math.max(maxStreak, currentStreak);
    lastDate = d;
  });

  // Energy
  const avgEnergy = +(
    monthly.reduce((s, c) => s + (c.energy || 0), 0) / monthly.length
  ).toFixed(1);
  const bestDay = monthly.reduce(
    (best, c) => (c.energy > (best?.energy || 0) ? c : best),
    monthly[0]
  );

  // Sleep
  const sleepEntries = monthly.filter((c) => c.sleep_hours != null);
  const avgSleep = sleepEntries.length
    ? +(
        sleepEntries.reduce((s, c) => s + c.sleep_hours, 0) / sleepEntries.length
      ).toFixed(1)
    : null;
  const bestSleep = sleepEntries.length
    ? sleepEntries.reduce(
        (best, c) => (c.sleep_hours > (best?.sleep_hours || 0) ? c : best),
        sleepEntries[0]
      )
    : null;

  // Mood
  const moodCounts = {};
  monthly.forEach((c) => {
    const m = c.mood || "neutral";
    moodCounts[m] = (moodCounts[m] || 0) + 1;
  });
  const topMoodEntry = Object.entries(moodCounts).sort((a, b) => b[1] - a[1])[0];
  const moodDistribution = Object.entries(moodCounts)
    .sort((a, b) => b[1] - a[1])
    .map(([mood, count]) => ({ mood, count }));

  // Symptoms
  const symptomCounts = {};
  monthly.forEach((c) =>
    (c.symptoms || []).forEach((s) => {
      if (s !== "none") symptomCounts[s] = (symptomCounts[s] || 0) + 1;
    })
  );
  const topSymptoms = Object.entries(symptomCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([symptom, count]) => ({ symptom, count }));

  // Practices
  const practiceCounts = {};
  monthly.forEach((c) =>
    (c.practices || []).forEach((p) => {
      practiceCounts[p] = (practiceCounts[p] || 0) + 1;
    })
  );
  const topPracticeEntry = Object.entries(practiceCounts).sort(
    (a, b) => b[1] - a[1]
  )[0];
  const practiceDiversity = Object.keys(practiceCounts).length;
  const mealCount = practiceCounts["anti_inflammatory_meal"] || 0;

  // Notes — most recent with content
  const notesWithContent = monthly.filter((c) => c.notes && c.notes.trim());
  const noteHighlight =
    notesWithContent.length > 0
      ? notesWithContent[notesWithContent.length - 1]
      : null;

  return {
    checkinCount,
    daysTrackedPct,
    maxStreak,
    avgEnergy,
    bestDay,
    avgSleep,
    bestSleep,
    topMoodEntry,
    moodDistribution,
    topSymptoms,
    topPracticeEntry,
    practiceDiversity,
    mealCount,
    noteHighlight,
  };
}

export default function VidaRewind({ checkins, user, onClose }) {
  const [slide, setSlide] = useState(0);
  const [favoriteRecipes, setFavoriteRecipes] = useState([]);
  const stats = useMemo(() => computeRewindStats(checkins), [checkins]);

  useEffect(() => {
    base44.entities.Favorite.list()
      .then((favs) =>
        setFavoriteRecipes(favs.filter((f) => f.resource_category === "recipe"))
      )
      .catch(() => {});
  }, []);

  const slides = useMemo(() => {
    if (!stats) return [];
    const s = ["intro", "checkins"];
    if (stats.avgEnergy) s.push("energy");
    if (stats.avgSleep) s.push("sleep");
    if (stats.topMoodEntry) s.push("mood");
    if (stats.topSymptoms.length) s.push("symptoms");
    if (stats.topPracticeEntry) s.push("practices");
    s.push("meals");
    if (stats.noteHighlight) s.push("note");
    s.push("outro");
    return s;
  }, [stats]);

  const next = useCallback(() => {
    setSlide((prev) => Math.min(prev + 1, slides.length - 1));
  }, [slides.length]);

  const prev = useCallback(() => {
    setSlide((p) => Math.max(0, p - 1));
  }, []);

  useEffect(() => {
    const handler = (e) => {
      if (e.key === "ArrowRight" || e.key === " ") {
        e.preventDefault();
        next();
      } else if (e.key === "ArrowLeft") {
        prev();
      } else if (e.key === "Escape") {
        onClose();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [next, prev, onClose]);

  if (!stats || slides.length === 0) return null;

  const currentSlide = slides[slide];
  const isForest = FOREST_SLIDES.has(currentSlide);
  const isLast = slide === slides.length - 1;

  const renderSlide = () => {
    switch (currentSlide) {
      case "intro":
        return (
          <div className="text-center">
            <motion.div
              initial={{ scale: 0, rotate: -20 }}
              animate={{ scale: 1, rotate: 0 }}
              transition={{ delay: 0.1, type: "spring", stiffness: 200 }}
              className="inline-block mb-6"
            >
              <Sparkles className="w-14 h-14 mx-auto" strokeWidth={1.2} />
            </motion.div>
            <h1 className="font-heading text-5xl sm:text-6xl mb-4">
              Lab Notes
            </h1>
            <p className="text-lg opacity-80">A look back at your month</p>
            <p className="text-sm opacity-50 mt-10 animate-pulse">
              Tap to begin →
            </p>
          </div>
        );

      case "checkins":
        return (
          <div className="text-center">
            <p className="text-xs uppercase tracking-widest opacity-60 mb-4">
              You showed up
            </p>
            <p className="font-heading text-7xl sm:text-8xl mb-4">
              <CountUp key={slide} value={stats.checkinCount} />
            </p>
            <p className="text-xl mb-6">check-ins this month</p>
            <p className="text-sm opacity-70">
              You tracked {stats.daysTrackedPct}% of days
            </p>
            {stats.maxStreak > 2 && (
              <p className="text-sm opacity-70 mt-2">
                Longest streak: {stats.maxStreak} days in a row
              </p>
            )}
          </div>
        );

      case "energy":
        return (
          <div className="text-center">
            <p className="text-xs uppercase tracking-widest opacity-60 mb-4">
              Your energy
            </p>
            <p className="font-heading text-7xl sm:text-8xl mb-4">
              <CountUp key={slide} value={stats.avgEnergy} decimals={1} />
              /5
            </p>
            <p className="text-xl mb-6">average energy</p>
            <p className="text-sm opacity-70">
              Your best day was {formatDate(stats.bestDay.checkin_date)} at{" "}
              {stats.bestDay.energy}/5
            </p>
          </div>
        );

      case "sleep":
        return (
          <div className="text-center">
            <p className="text-xs uppercase tracking-widest opacity-60 mb-4">
              Your sleep
            </p>
            <p className="font-heading text-7xl sm:text-8xl mb-4">
              <CountUp key={slide} value={stats.avgSleep} decimals={1} suffix="h" />
            </p>
            <p className="text-xl mb-6">average sleep per night</p>
            {stats.bestSleep && (
              <p className="text-sm opacity-70">
                Your best night was {formatDate(stats.bestSleep.checkin_date)} at{" "}
                {stats.bestSleep.sleep_hours}h
              </p>
            )}
          </div>
        );

      case "mood":
        return (
          <div className="text-center">
            <p className="text-xs uppercase tracking-widest opacity-60 mb-4">
              Your mood landscape
            </p>
            <p className="font-heading text-5xl sm:text-6xl mb-4 capitalize">
              {labelMood(stats.topMoodEntry[0])}
            </p>
            <p className="text-lg mb-8 opacity-80">
              was your most common mood
            </p>
            <div className="space-y-2 max-w-sm mx-auto">
              {stats.moodDistribution.slice(0, 4).map((m) => (
                <div key={m.mood} className="flex items-center gap-3">
                  <span className="text-sm w-24 text-left capitalize">
                    {labelMood(m.mood)}
                  </span>
                  <div className="flex-1 h-5 rounded-full bg-white/15 overflow-hidden">
                    <div
                      className="h-full rounded-full bg-white/50"
                      style={{
                        width: `${
                          (m.count / stats.moodDistribution[0].count) * 100
                        }%`,
                      }}
                    />
                  </div>
                  <span className="text-xs w-8 text-right opacity-70">
                    {m.count}
                  </span>
                </div>
              ))}
            </div>
          </div>
        );

      case "symptoms":
        return (
          <div className="text-center">
            <p className="text-xs uppercase tracking-widest opacity-60 mb-4">
              What you tracked
            </p>
            <p className="font-heading text-4xl sm:text-5xl mb-4">
              {labelSymptom(stats.topSymptoms[0].symptom)}
            </p>
            <p className="text-lg mb-8 opacity-80">
              was your most frequent symptom
            </p>
            <div className="space-y-1 max-w-sm mx-auto">
              {stats.topSymptoms.map((s, i) => (
                <p key={s.symptom} className="text-sm opacity-70">
                  {i + 1}. {labelSymptom(s.symptom)} — {s.count}×
                </p>
              ))}
            </div>
          </div>
        );

      case "practices":
        return (
          <div className="text-center">
            <p className="text-xs uppercase tracking-widest opacity-60 mb-4">
              Your wellness practices
            </p>
            <p className="font-heading text-4xl sm:text-5xl mb-4">
              {PRACTICE_LABELS[stats.topPracticeEntry[0]] ||
                stats.topPracticeEntry[0]}
            </p>
            <p className="text-lg mb-6 opacity-80">
              {stats.topPracticeEntry[1]} times this month
            </p>
            <p className="text-sm opacity-70">
              You tried {stats.practiceDiversity} different practices
            </p>
          </div>
        );

      case "meals":
        return (
          <div className="text-center">
            <p className="text-xs uppercase tracking-widest opacity-60 mb-4">
              Nourishing meals
            </p>
            <p className="font-heading text-7xl sm:text-8xl mb-4">
              <CountUp key={slide} value={stats.mealCount} />
            </p>
            <p className="text-xl mb-6">anti-inflammatory meals logged</p>
            {favoriteRecipes.length > 0 ? (
              <p className="text-sm opacity-70">
                Plus {favoriteRecipes.length} saved{" "}
                {favoriteRecipes.length === 1 ? "recipe" : "recipes"} in your
                library
              </p>
            ) : (
              <p className="text-sm opacity-70">
                Save recipes in your library to see them here next month
              </p>
            )}
          </div>
        );

      case "note":
        return (
          <div className="text-center max-w-lg mx-auto">
            <p className="text-xs uppercase tracking-widest opacity-60 mb-4">
              A moment you noted
            </p>
            <p className="text-sm opacity-70 mb-6">
              On {formatDate(stats.noteHighlight.checkin_date)}, you wrote:
            </p>
            <p className="font-heading text-2xl sm:text-3xl italic leading-relaxed">
              &ldquo;{stats.noteHighlight.notes}&rdquo;
            </p>
          </div>
        );

      case "outro":
        return (
          <div className="text-center">
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ delay: 0.15, type: "spring", stiffness: 200 }}
              className="inline-block mb-6"
            >
              <Heart className="w-14 h-14 mx-auto" strokeWidth={1.2} />
            </motion.div>
            <h2 className="font-heading text-4xl sm:text-5xl mb-4">
              That&rsquo;s your month in the Lab
            </h2>
            <p className="text-lg opacity-70 mb-8">See you next month</p>
            <button
              onClick={onClose}
              className="inline-flex items-center gap-2 rounded-full px-8 py-3.5 bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors"
            >
              Finish
            </button>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center overflow-hidden">
      <div
        className={`absolute inset-0 transition-colors duration-500 ${
          isForest ? "bg-[#2E463E] text-[#F9F8F5]" : "bg-[#F9F8F5] text-[#2E463E]"
        }`}
      />

      <button
        onClick={onClose}
        className="absolute top-5 right-5 z-20 w-10 h-10 rounded-full flex items-center justify-center hover:bg-black/10 transition-colors"
        aria-label="Close"
      >
        <X className="w-5 h-5" />
      </button>

      <div
        className="relative z-10 w-full max-w-2xl px-6 py-12 cursor-pointer min-h-[60vh] flex items-center justify-center"
        onClick={isLast ? undefined : next}
      >
        <AnimatePresence mode="wait">
          <motion.div
            key={slide}
            initial={{ opacity: 0, x: 50 }}
            animate={{ opacity: 1, x: 0 }}
            exit={{ opacity: 0, x: -50 }}
            transition={{ duration: 0.35, ease: "easeInOut" }}
            className="w-full"
          >
            {renderSlide()}
          </motion.div>
        </AnimatePresence>
      </div>

      <div className="absolute bottom-8 left-0 right-0 flex justify-center gap-2 z-20">
        {slides.map((_, i) => (
          <button
            key={i}
            onClick={(e) => {
              e.stopPropagation();
              setSlide(i);
            }}
            className={`h-2 rounded-full transition-all bg-current ${
              i === slide ? "w-8 opacity-100" : "w-2 opacity-30"
            }`}
            aria-label={`Slide ${i + 1}`}
          />
        ))}
      </div>

      {!isLast && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            next();
          }}
          className="absolute bottom-7 right-8 z-20 w-12 h-12 rounded-full flex items-center justify-center hover:bg-black/10 transition-colors"
          aria-label="Next"
        >
          <ChevronRight className="w-6 h-6" />
        </button>
      )}
    </div>
  );
}