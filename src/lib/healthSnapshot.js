import { labelSymptom, labelMood } from "@/lib/insights";

// Builds a structured "Vida Health Snapshot" from daily check-ins.
// Shared by DoctorPrep (printable snapshot) and BookingModal (email to practice).
export function buildHealthSnapshot(checkins) {
  if (!checkins || !checkins.length) return null;

  const sorted = [...checkins].sort((a, b) =>
    a.checkin_date < b.checkin_date ? -1 : 1
  );
  const first = sorted[0].checkin_date;
  const last = sorted[sorted.length - 1].checkin_date;

  const avgEnergy = +(
    checkins.reduce((s, c) => s + (c.energy || 0), 0) / checkins.length
  ).toFixed(1);

  const sleepEntries = checkins.filter((c) => c.sleep_hours != null);
  const avgSleep = sleepEntries.length
    ? +(
        sleepEntries.reduce((s, c) => s + c.sleep_hours, 0) /
        sleepEntries.length
      ).toFixed(1)
    : null;

  const moodCounts = {};
  checkins.forEach((c) => {
    const m = c.mood || "neutral";
    moodCounts[m] = (moodCounts[m] || 0) + 1;
  });
  const topMoods = Object.entries(moodCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([m, c]) => ({ mood: labelMood(m), count: c }));

  const symptomCounts = {};
  checkins.forEach((c) =>
    (c.symptoms || []).forEach((s) => {
      if (s !== "none") symptomCounts[s] = (symptomCounts[s] || 0) + 1;
    })
  );
  const topSymptoms = Object.entries(symptomCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([s, c]) => ({ symptom: labelSymptom(s), count: c }));

  const painEntries = checkins.filter((c) => c.pain_level > 0);
  const avgPain = painEntries.length
    ? +(
        painEntries.reduce((s, c) => s + c.pain_level, 0) / painEntries.length
      ).toFixed(1)
    : 0;

  const lowEnergyDays = checkins.filter((c) => c.energy <= 2).length;
  const poorSleepDays = checkins.filter(
    (c) => c.sleep_quality != null && c.sleep_quality <= 2
  ).length;

  const questions = [];
  if (topSymptoms[0])
    questions.push(
      `My "${topSymptoms[0].symptom}" appears frequently — is there anything worth investigating?`
    );
  if (lowEnergyDays >= 5)
    questions.push(
      `I've had ${lowEnergyDays} low-energy days in this window — could we look at possible causes?`
    );
  if (avgPain >= 2)
    questions.push(
      `My average pain on symptomatic days is moderate-to-severe — what's worth checking?`
    );
  if (poorSleepDays >= 5)
    questions.push(
      `Sleep quality has been low on ${poorSleepDays} days — any guidance on improving it?`
    );
  if (questions.length === 0)
    questions.push(
      "Based on my tracking, is there anything I should be watching more closely?"
    );

  return {
    first,
    last,
    total: checkins.length,
    avgEnergy,
    avgSleep,
    avgPain,
    topMoods,
    topSymptoms,
    lowEnergyDays,
    poorSleepDays,
    questions,
  };
}