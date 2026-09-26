export const COMMUNITY_CATEGORIES = [
  { value: "general", label: "General" },
  { value: "sleep", label: "Sleep" },
  { value: "mood", label: "Mood" },
  { value: "nutrition", label: "Nutrition" },
  { value: "movement", label: "Movement" },
  { value: "stress", label: "Stress" },
  { value: "chronic_conditions", label: "Chronic Conditions" },
  { value: "treatments", label: "Treatments" },
  { value: "other", label: "Other" },
];

export const categoryLabel = (value) =>
  COMMUNITY_CATEGORIES.find((c) => c.value === value)?.label || "General";