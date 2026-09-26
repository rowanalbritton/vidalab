import React, { useState, useEffect, useMemo } from "react";
import { Link } from "react-router-dom";
import { base44 } from "@/api/base44Client";
import { useAuth } from "@/lib/AuthContext";
import MembershipGate from "@/components/MembershipGate";
import DoctorMap from "@/components/DoctorMap";
import BookingModal from "@/components/doctors/BookingModal";
import MyAppointments from "@/components/doctors/MyAppointments";
import {
  MapPin,
  Search,
  Phone,
  Mail,
  Globe,
  Stethoscope,
  ArrowLeft,
  UserPlus,
  Building2,
  Filter,
  Map as MapIcon,
  LayoutGrid,
  Calendar,
  Contact as ContactIcon,
} from "lucide-react";
import Loader from "@/components/Loader";
import GoogleSyncButton from "@/components/GoogleSyncButton";

const CATEGORY_LABELS = {
  autoimmune: "Autoimmune",
  neurological: "Neurological",
  cardiovascular: "Cardiovascular",
  endocrine: "Endocrine",
  musculoskeletal: "Musculoskeletal",
  gastrointestinal: "Gastrointestinal",
  respiratory: "Respiratory",
  mental_health: "Mental Health",
  chronic_pain: "Chronic Pain",
  dysautonomia: "Dysautonomia",
  gynecological: "Gynecological",
  other: "Other",
};

export default function DoctorFinder() {
  const { user } = useAuth();
  const isVidaPlus = user?.membership === "vida_plus";
  const [doctors, setDoctors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("");
  const [location, setLocation] = useState("");
  const [viewMode, setViewMode] = useState("list");
  const [bookingDoctor, setBookingDoctor] = useState(null);
  const [appointments, setAppointments] = useState([]);
  const [appointmentsLoading, setAppointmentsLoading] = useState(true);

  useEffect(() => {
    if (!isVidaPlus) {
      setLoading(false);
      return;
    }
    base44.entities.Doctor.list("sort_order", 200)
      .then(setDoctors)
      .catch(() => {})
      .finally(() => setLoading(false));
    base44.entities.Appointment.list("-created_date", 50)
      .then(setAppointments)
      .catch(() => {})
      .finally(() => setAppointmentsLoading(false));
  }, [isVidaPlus]);

  const handleCancelAppointment = async (aptId) => {
    try {
      await base44.entities.Appointment.update(aptId, { status: "cancelled" });
      setAppointments((prev) =>
        prev.map((a) => (a.id === aptId ? { ...a, status: "cancelled" } : a))
      );
    } catch (e) {}
  };

  const refreshAppointments = () => {
    base44.entities.Appointment.list("-created_date", 50)
      .then(setAppointments)
      .catch(() => {});
  };

  const filtered = useMemo(() => {
    return doctors.filter((d) => {
      const q = search.toLowerCase().trim();
      if (q) {
        const haystack = [d.practice_name, d.specialty, d.city, d.state, d.notes]
          .filter(Boolean)
          .join(" ")
          .toLowerCase();
        if (!haystack.includes(q)) return false;
      }
      if (category && d.category !== category) return false;
      if (location) {
        const loc = location.toLowerCase().trim();
        const docLoc = [d.city, d.state, d.zip_code].filter(Boolean).join(" ").toLowerCase();
        if (!docLoc.includes(loc)) return false;
      }
      return true;
    });
  }, [doctors, search, category, location]);

  if (!isVidaPlus) {
    return (
      <MembershipGate title="Local Doctor Finder is a Vida+ feature">
        Find specialists and doctors in your area who match your needs — no more guessing where to turn next.
        Unlock the full directory with Vida+.
      </MembershipGate>
    );
  }

  return (
    <main className="max-w-5xl mx-auto px-5 sm:px-8 py-10">
      {/* Header */}
      <div className="mb-8">
        <div className="flex items-center justify-between mb-4">
          <Link
            to="/daily-signals"
            className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary transition-colors"
          >
            <ArrowLeft className="w-4 h-4" /> Back to Daily Signals
          </Link>
          <span className="text-xs uppercase tracking-widest text-muted-foreground">Vida+ Directory</span>
        </div>
        <h1 className="font-heading text-4xl text-primary mt-1">Local Doctor Finder</h1>
        <p className="text-muted-foreground mt-2 max-w-xl">
          Search for specialists by name, specialty, or location. Filter by condition category to find
          the right care for what you're navigating.
        </p>
      </div>

      {/* My Appointments */}
      <MyAppointments
        appointments={appointments}
        onCancel={handleCancelAppointment}
        loading={appointmentsLoading}
      />

      {appointments.length > 0 && (
        <div className="mb-6 flex items-center gap-3">
          <GoogleSyncButton
            connectorId="6ab2084c0df62ea6055b6758"
            functionName="sync-doctors-to-contacts"
            label="Sync doctors to Google Contacts"
            connectLabel="Connect Google Contacts"
            successLabel="Contacts synced"
            icon={ContactIcon}
          />
        </div>
      )}

      {/* Search & filters */}
      <div className="rounded-2xl bg-card border border-border p-5 sm:p-6 mb-6">
        <div className="grid sm:grid-cols-3 gap-4">
          {/* Search */}
          <div className="sm:col-span-1">
            <label className="block text-xs uppercase tracking-widest text-muted-foreground mb-1.5">
              Search
            </label>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Name or specialty"
                className="w-full rounded-xl border border-border bg-background pl-10 pr-4 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary"
              />
            </div>
          </div>

          {/* Category */}
          <div>
            <label className="block text-xs uppercase tracking-widest text-muted-foreground mb-1.5">
              Category
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="w-full rounded-xl border border-border bg-background px-4 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary"
            >
              <option value="">All categories</option>
              {Object.entries(CATEGORY_LABELS).map(([val, label]) => (
                <option key={val} value={val}>
                  {label}
                </option>
              ))}
            </select>
          </div>

          {/* Location */}
          <div>
            <label className="block text-xs uppercase tracking-widest text-muted-foreground mb-1.5">
              Location
            </label>
            <div className="relative">
              <MapPin className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <input
                type="text"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                placeholder="City, state, or ZIP"
                className="w-full rounded-xl border border-border bg-background pl-10 pr-4 py-2.5 text-sm text-foreground focus:outline-none focus:border-primary"
              />
            </div>
          </div>
        </div>

        {/* Active filters + count */}
        <div className="flex items-center justify-between mt-4 pt-4 border-t border-border">
          <p className="text-sm text-muted-foreground">
            {loading ? "Loading…" : `${filtered.length} ${filtered.length === 1 ? "doctor" : "doctors"} found`}
          </p>
          {(search || category || location) && (
            <button
              onClick={() => {
                setSearch("");
                setCategory("");
                setLocation("");
              }}
              className="inline-flex items-center gap-1.5 text-sm text-muted-foreground hover:text-primary transition-colors"
            >
              <Filter className="w-3.5 h-3.5" /> Clear filters
            </button>
          )}
        </div>
      </div>

      {/* View toggle */}
      {!loading && filtered.length > 0 && (
        <div className="flex items-center justify-between mb-5">
          <div className="inline-flex rounded-full border border-border p-1 bg-card">
            <button
              onClick={() => setViewMode("list")}
              className={`inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
                viewMode === "list" ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-primary"
              }`}
            >
              <LayoutGrid className="w-4 h-4" /> List
            </button>
            <button
              onClick={() => setViewMode("map")}
              className={`inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full text-sm font-medium transition-colors ${
                viewMode === "map" ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-primary"
              }`}
            >
              <MapIcon className="w-4 h-4" /> Map
            </button>
          </div>
          {viewMode === "map" && (
            <p className="text-xs text-muted-foreground hidden sm:block">
              Tap a marker to see specialists at that location
            </p>
          )}
        </div>
      )}

      {/* Map view */}
      {!loading && viewMode === "map" && filtered.length > 0 && (
        <div className="mb-6">
          <DoctorMap doctors={filtered} />
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="flex justify-center py-20">
          <Loader />
        </div>
      )}

      {/* Empty state */}
      {!loading && filtered.length === 0 && (
        <div className="text-center py-20 rounded-2xl border border-dashed border-border">
          <Stethoscope className="w-10 h-10 text-muted-foreground mx-auto mb-4" strokeWidth={1.5} />
          <p className="text-muted-foreground">
            {doctors.length === 0
              ? "No doctors in the directory yet."
              : "No doctors match your search. Try adjusting your filters."}
          </p>
        </div>
      )}

      {/* Results grid */}
      {!loading && filtered.length > 0 && viewMode === "list" && (
        <div className="grid sm:grid-cols-2 gap-4">
          {filtered.map((doc) => (
            <div
              key={doc.id}
              className="rounded-2xl bg-card border border-border p-5 flex flex-col"
            >
              {/* Header */}
              <div className="flex items-start justify-between gap-3 mb-3">
                <div className="flex items-start gap-3">
                  <div className="w-10 h-10 rounded-xl bg-vida-sage/20 flex items-center justify-center shrink-0">
                    <Building2 className="w-5 h-5 text-vida-moss" strokeWidth={1.5} />
                  </div>
                  <div>
                    <h3 className="font-heading text-lg text-primary leading-tight">{doc.practice_name}</h3>
                    <p className="text-sm text-muted-foreground mt-0.5">{doc.specialty}</p>
                  </div>
                </div>
                {doc.accepting_new_patients && (
                  <span className="inline-flex items-center gap-1 rounded-full bg-vida-moss/15 px-2.5 py-1 text-xs font-medium text-vida-moss shrink-0">
                    <UserPlus className="w-3 h-3" /> Accepting
                  </span>
                )}
              </div>

              {/* Category badge */}
              {doc.category && (
                <span className="inline-flex items-center self-start rounded-full bg-muted px-2.5 py-1 text-xs font-medium text-muted-foreground mb-3">
                  {CATEGORY_LABELS[doc.category] || doc.category}
                </span>
              )}

              {/* Contact details */}
              <div className="space-y-2 mt-auto">
                {(doc.address || doc.city || doc.state) && (
                  <div className="flex items-start gap-2 text-sm text-muted-foreground">
                    <MapPin className="w-4 h-4 shrink-0 mt-0.5 text-vida-moss" strokeWidth={1.5} />
                    <span>
                      {[doc.address, [doc.city, doc.state].filter(Boolean).join(", "), doc.zip_code]
                        .filter(Boolean)
                        .join(", ")}
                    </span>
                  </div>
                )}
                {doc.phone && (
                  <a
                    href={`tel:${doc.phone}`}
                    className="flex items-center gap-2 text-sm text-muted-foreground hover:text-primary transition-colors"
                  >
                    <Phone className="w-4 h-4 shrink-0 text-vida-moss" strokeWidth={1.5} />
                    <span>{doc.phone}</span>
                  </a>
                )}
                {doc.email && (
                  <a
                    href={`mailto:${doc.email}`}
                    className="flex items-center gap-2 text-sm text-muted-foreground hover:text-primary transition-colors truncate"
                  >
                    <Mail className="w-4 h-4 shrink-0 text-vida-moss" strokeWidth={1.5} />
                    <span className="truncate">{doc.email}</span>
                  </a>
                )}
                {doc.website && (
                  <a
                    href={doc.website}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-center gap-2 text-sm text-muted-foreground hover:text-primary transition-colors truncate"
                  >
                    <Globe className="w-4 h-4 shrink-0 text-vida-moss" strokeWidth={1.5} />
                    <span className="truncate">{doc.website.replace(/^https?:\/\//, "")}</span>
                  </a>
                )}
              </div>

              {/* Notes */}
              {doc.notes && (
                <p className="text-xs text-muted-foreground mt-3 pt-3 border-t border-border leading-relaxed">
                  {doc.notes}
                </p>
              )}

              {/* Book appointment */}
              <button
                onClick={() => setBookingDoctor(doc)}
                className="mt-3 pt-3 border-t border-border w-full inline-flex items-center justify-center gap-2 py-2.5 rounded-xl bg-primary/5 text-primary text-sm font-medium hover:bg-primary/10 transition-colors"
              >
                <Calendar className="w-4 h-4" /> Book Appointment
              </button>
            </div>
          ))}
        </div>
      )}
      {bookingDoctor && (
        <BookingModal
          doctor={bookingDoctor}
          onClose={() => setBookingDoctor(null)}
          onBooked={refreshAppointments}
        />
      )}
    </main>
  );
}