// Educational insight engine for Vida Lab — shared backend module.
// Rule-based, deterministic, no diagnosis — strictly wellness-side observations.
// Mirrors src/lib/insights.js (frontend). Keep both in sync when adding rules.

const MOOD_LABELS = {
  calm: "calm", happy: "bright", neutral: "steady", anxious: "anxious",
  sad: "low", irritable: "irritable", motivated: "motivated",
};

const SYMPTOM_LABELS = {
  headache: "headaches", cramps: "cramps", bloating: "bloating",
  fatigue: "fatigue", breast_tenderness: "tenderness", acne: "skin changes",
  backache: "back ache", nausea: "nausea", brain_fog: "brain fog",
  cravings: "cravings", none: "no notable symptoms",
};

export function labelMood(mood) {
  return MOOD_LABELS[mood] || mood;
}

export function labelSymptom(s) {
  return SYMPTOM_LABELS[s] || s;
}

const CYCLE_LABELS = {
  menstrual: "menstrual", follicular: "follicular",
  ovulation: "ovulation", luteal: "luteal", not_tracking: "not tracking",
};

export function labelCycle(phase) {
  return CYCLE_LABELS[phase] || phase;
}

// Returns an educational insight string based on the check-in signals.
export function generateInsight(checkin) {
  const {
    energy = 3, sleep_hours, sleep_quality, mood, pain_level = 0,
    cycle_phase = "not_tracking", symptoms = [],
  } = checkin;

  const has = (s) => Array.isArray(symptoms) && symptoms.includes(s);
  const lowEnergy = energy <= 2;
  const poorSleep = (sleep_quality && sleep_quality <= 2) || (sleep_hours != null && sleep_hours < 6);
  const highPain = pain_level >= 2;
  const luteal = cycle_phase === "luteal";
  const menstrual = cycle_phase === "menstrual";
  const tracking = cycle_phase !== "not_tracking";

  if (lowEnergy && poorSleep) {
    return "Your energy dipped on a night of poor sleep — this is one of the most consistent patterns in chronic health. Sleep is the lever your body uses to restore hormones, mood, and focus. A short wind-down (dim light, no screens 30 min before bed) can shift tomorrow's energy more than any supplement.";
  }

  if (has("headache") && poorSleep) {
    return "Headaches often track sleep, stress, and hydration. Tracking their timing (not just their pain) is what helps you and a clinician see the pattern. Consistent meal timing and enough water can reduce frequency for some people.";
  }

  if (has("brain_fog") && poorSleep) {
    return "Brain fog often tracks sleep more than anything else. When sleep is fragmented, working memory and focus drop measurably. Before blaming stress, look at the sleep column of your pattern — it's usually doing more of the explaining.";
  }

  if (has("bloating")) {
    return "Bloating can follow patterns — food, stress, sleep, or activity. Smaller, regular meals and enough water (counterintuitively) help. If bloating is new, persistent, or worsening, flag it for a clinician.";
  }

  if (highPain) {
    return "Pain that shows up repeatedly is worth tracking carefully — the timing, location, and triggers. If pain regularly stops you from daily activities, bring it to a clinician — that level of pain is worth investigating.";
  }

  // Cycle-specific insights (only when the user is tracking their cycle)
  if (tracking) {
    if (lowEnergy && luteal) {
      return "Lower energy in the luteal phase (the week or two before your period) is common and well-documented. Progesterone is elevated, which can feel calming but also draining. Eating enough — especially complex carbs and iron-rich foods — and protecting rest this week is not laziness; it's physiology.";
    }
    if (has("headache") && (luteal || menstrual)) {
      return "Hormonal headaches often cluster around the luteal and menstrual phases as estrogen and progesterone shift. Tracking their timing (not just their pain) is what helps you and a clinician see the pattern. Hydration and consistent meal timing can reduce frequency for some people.";
    }
    if ((mood === "irritable" || mood === "anxious") && luteal) {
      return "Mood shifts in the luteal phase are real and measurable — not a character flaw. Falling estrogen and progesterone affect serotonin. Naming the pattern ('this is luteal, not me') is the first step. If these shifts feel severe or disrupt your life, that's worth bringing to a clinician.";
    }
    if ((has("cramps") || highPain) && menstrual) {
      return "Cramps during your period are driven by prostaglandins — compounds that help the uterus contract. Heat, movement, and anti-inflammatory foods (omega-3s, ginger) can ease them. If pain regularly stops you from daily activities, track it and raise it with a clinician — that level of pain is worth investigating.";
    }
    if (has("bloating") && luteal) {
      return "Bloating in the luteal phase is common — progesterone slows digestion, and water retention rises. Smaller, regular meals and enough water (counterintuitively) help. If bloating is new, persistent, or unrelated to your cycle, flag it for a clinician.";
    }
  }

  if (mood === "sad" || mood === "anxious") {
    return "Noticing a low or anxious day is the point of tracking — not the problem. A single day is data; a streak is a pattern. If low or anxious days cluster for two weeks or more, that's a pattern worth naming to a clinician.";
  }

  if (energy >= 4 && !poorSleep) {
    return "Good energy on rested sleep is your baseline state — worth noticing so you can recognize when you drift from it. This is what 'well' looks like for you right now. Protect the sleep that produces it.";
  }

  return "Every check-in adds a dot to your pattern. On its own a day is just a day; over weeks, these dots become the picture you bring to a clinician — not a diagnosis, but better questions.";
}

export function summarize(checkin) {
  const parts = [];
  parts.push(`Energy ${checkin.energy ?? "—"}/5`);
  if (checkin.mood) parts.push(labelMood(checkin.mood));
  if (Array.isArray(checkin.symptoms) && checkin.symptoms.length && !checkin.symptoms.includes("none"))
    parts.push(checkin.symptoms.map(labelSymptom).join(", "));
  return parts.join(" · ");
}