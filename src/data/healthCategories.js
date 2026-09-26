export const CATEGORIES = [
  { id: "all", label: "All" },
  { id: "recipe", label: "Recipes" },
  { id: "exercise", label: "Exercises" },
  { id: "meditation", label: "Meditations" },
  { id: "supplement", label: "Supplements" },
  { id: "habit", label: "Habits" },
];

export const SUBCATEGORIES = {
  recipe: ["anti-inflammatory", "breakfast", "lunch", "dinner", "snacks", "drinks"],
  exercise: ["push", "pull", "legs", "abs", "cardio", "pilates", "strength", "stretching", "yoga", "mobility", "education"],
  meditation: ["breathing", "body-scan", "mindfulness", "sleep"],
  supplement: ["anti-inflammatory", "sleep", "energy", "immune", "gut-health"],
  habit: ["sleep", "nutrition", "movement", "stress", "hydration"],
};

export const CATEGORY_LABELS = {
  recipe: "Recipe",
  exercise: "Exercise",
  meditation: "Meditation",
  supplement: "Supplement",
  habit: "Habit",
};

export const DIFFICULTY_LABELS = {
  gentle: "Gentle",
  easy: "Easy",
  moderate: "Moderate",
  advanced: "Advanced",
};

export const FOCUS_GROUPS = [
  {
    label: "Dietary",
    categories: ["recipe"],
    filters: [
      { label: "High Protein", tag: "high-protein" },
      { label: "Vegetarian", tag: "vegetarian" },
      { label: "Vegan", tag: "vegan" },
      { label: "Gluten-Free", tag: "gluten-free" },
      { label: "Low-Carb", tag: "low-carb" },
      { label: "Grain-Free", tag: "grain-free" },
    ],
  },
  {
    label: "Wellness Goals",
    categories: ["recipe", "exercise", "meditation", "supplement", "habit"],
    filters: [
      { label: "Anti-Inflammatory", tag: "anti-inflammatory" },
      { label: "Sleep Support", tag: "sleep" },
      { label: "Energy", tag: "energy" },
      { label: "Gut Health", tag: "gut-health" },
      { label: "Immune Support", tag: "immune" },
      { label: "Stress Relief", tag: "stress" },
      { label: "Pain Relief", tag: "pain" },
      { label: "Digestion", tag: "digestion" },
      { label: "Recovery", tag: "recovery" },
      { label: "Focus & Clarity", tag: "focus" },
    ],
  },
  {
    label: "Practical",
    categories: ["exercise", "meditation", "habit", "recipe"],
    filters: [
      { label: "Quick (≤5 min)", tag: "quick" },
      { label: "Desk-Friendly", tag: "desk-friendly" },
      { label: "Flare-Safe", tag: "flare-safe" },
      { label: "Chair-Friendly", tag: "chair-friendly" },
      { label: "One-Pot", tag: "one-pot", categories: ["recipe"] },
      { label: "No-Cook", tag: "no-cook", categories: ["recipe"] },
      { label: "Meal Prep", tag: "meal-prep", categories: ["recipe"] },
    ],
  },
  {
    label: "Equipment",
    categories: ["exercise"],
    filters: [
      { label: "Bodyweight", tag: "bodyweight" },
      { label: "Dumbbells", tag: "dumbbell" },
      { label: "Barbell", tag: "barbell" },
      { label: "Cable", tag: "cable" },
      { label: "Machine", tag: "machine" },
      { label: "Kettlebell", tag: "kettlebell" },
    ],
  },
  {
    label: "Audience",
    categories: ["recipe", "exercise", "meditation", "supplement", "habit"],
    filters: [
      { label: "For Men", tag: "mens-health" },
      { label: "For Women", tag: "womens-health" },
      { label: "Seniors", tag: "seniors" },
      { label: "Injured / Rehab", tag: "injured" },
      { label: "Beginners", tag: "beginners" },
      { label: "Athletes", tag: "athletes" },
      { label: "Prenatal", tag: "prenatal" },
    ],
  },
];