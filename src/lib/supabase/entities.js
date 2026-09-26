import { createEntity } from "./createEntity";

// ============================================================
// Supabase entity wrappers — mirror the Base44 SDK entity API.
// Swap `base44.entities.X` → `supaEntities.X` in pages, one at a time.
//
// All entities now have SQL tables (see src/supabase/migrations/).
// Field maps handle camelCase ↔ snake_case where needed.
// ============================================================

// User-owned tables (created_by_id <-> user_id mapping)
export const DailyCheckin = createEntity({ table: "daily_checkins", userOwned: true });
export const Experiment = createEntity({ table: "experiments", userOwned: true });
export const Favorite = createEntity({ table: "favorites", userOwned: true });
export const Treatment = createEntity({ table: "treatments", userOwned: true });
export const Appointment = createEntity({ table: "appointments", userOwned: true });
export const ExperimentLog = createEntity({ table: "experiment_logs", userOwned: true });

// Base44Purchase uses camelCase fields that need snake_case mapping
export const Base44Purchase = createEntity({
  table: "purchases",
  userOwned: true,
  fieldMap: {
    checkoutSessionId: "checkout_session_id",
    orderId: "order_id",
    appUserId: "user_id",
    buyerEmail: "buyer_email",
    productId: "product_id",
    productName: "product_name",
    subscriptionId: "subscription_id",
    paidAt: "paid_at",
    canceledAt: "canceled_at",
  },
});

// Public read, admin write
export const Doctor = createEntity({ table: "doctors" });
export const HealthResource = createEntity({ table: "health_resources", publicOnly: true });
export const DiseaseReport = createEntity({ table: "disease_reports", publicOnly: true });
export const Explainer = createEntity({ table: "explainers", publicOnly: true });
export const SubstackArticle = createEntity({ table: "substack_articles" });
export const ResearchPaper = createEntity({ table: "research_papers" });

// Public insert, admin read/update/delete
export const NewsletterSignup = createEntity({ table: "newsletter_signups" });

// Community tables — author_id is hidden from SELECT by column-level grant, so
// the column lists are explicit to avoid permission errors.
//
// The DB columns are body / created_at / author_id (canonical, shared with iOS
// — see supabase/migrations/20260924140000_reconcile_community_schema.sql). The
// fieldMap translates them back to the content / created_date names the
// components already read, so the schema could be reconciled without touching
// every component that renders a post.
const communityFieldMap = {
  created_by_id: "author_id",
  content: "body",
  created_date: "created_at",
  updated_date: "updated_at",
};

export const CommunityPost = createEntity({
  table: "community_posts",
  userOwned: true,
  ownerColumn: "author_id",
  activeOnly: true,
  fieldMap: communityFieldMap,
  selectColumns:
    "id,title,body,category,display_name,status,flagged,created_at,updated_at",
});

export const CommunityReply = createEntity({
  table: "community_replies",
  userOwned: true,
  ownerColumn: "author_id",
  activeOnly: true,
  fieldMap: communityFieldMap,
  selectColumns:
    "id,post_id,body,display_name,status,flagged,created_at,updated_at",
});