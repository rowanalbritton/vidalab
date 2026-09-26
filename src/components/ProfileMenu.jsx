import React, { useState, useEffect, useRef } from "react";
import { Link, useNavigate } from "react-router-dom";
import { motion, AnimatePresence } from "framer-motion";
import { base44 } from "@/api/base44Client";
import { useAuth } from "@/lib/AuthContext";
import { Heart, Calendar, FlaskConical, LineChart, LogOut, ChevronDown, Sparkles } from "lucide-react";

export default function ProfileMenu() {
  const { user } = useAuth();
  const [open, setOpen] = useState(false);
  const [favCount, setFavCount] = useState(null);
  const ref = useRef(null);
  const navigate = useNavigate();

  useEffect(() => {
    if (!user) return;
    let alive = true;
    base44.entities.Favorite.list("-created_date", 500)
      .then((favs) => { if (alive) setFavCount(favs.length); })
      .catch(() => { if (alive) setFavCount(0); });
    return () => { alive = false; };
  }, [user]);

  useEffect(() => {
    const onClick = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    document.addEventListener("mousedown", onClick);
    return () => document.removeEventListener("mousedown", onClick);
  }, []);

  const handleLogout = async () => {
    setOpen(false);
    await base44.auth.logout();
    navigate("/");
  };

  if (!user) return null;

  const displayName = user.full_name || user.email?.split("@")[0] || "Member";
  const initials = displayName.split(" ").map((p) => p[0]).slice(0, 2).join("").toUpperCase();

  const links = [
    { icon: Heart, title: "Your favorites", desc: favCount != null ? `${favCount} saved` : "All your saved resources", path: "/favorites" },
    { icon: Calendar, title: "Daily Signals", desc: "Your check-ins & exportable history", path: "/daily-signals" },
    { icon: LineChart, title: "Pattern Map", desc: "How your signals correlate", path: "/pattern-map" },
    { icon: FlaskConical, title: "Vida Experiments", desc: "Your self-experiments", path: "/vida-experiments" },
  ];

  return (
    <div className="profile-menu" ref={ref}>
      <button
        className={`profile-trigger${open ? " active" : ""}`}
        onClick={() => setOpen(!open)}
        aria-expanded={open}
      >
        <span className="profile-avatar">{initials}</span>
        <span className="profile-name">{displayName.split(" ")[0]}</span>
        <ChevronDown size={14} strokeWidth={1.5} className={`profile-chevron${open ? " open" : ""}`} />
      </button>
      <AnimatePresence>
        {open && (
          <motion.div
            className="profile-dropdown"
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.25, ease: [0.25, 0.1, 0.25, 1] }}
          >
            <div className="profile-dropdown-head">
              <div className="profile-dropdown-name">{displayName}</div>
              <div className="profile-dropdown-email">{user.email}</div>
              {user.membership === "vida_plus" && (
                <span className="profile-dropdown-badge">Vida+ member</span>
              )}
            </div>
            <div className="profile-dropdown-items">
              {links.map((l) => (
                <Link
                  key={l.title}
                  to={l.path}
                  className="profile-dropdown-item"
                  onClick={() => setOpen(false)}
                >
                  <span className="profile-dropdown-icon"><l.icon size={16} strokeWidth={1.5} /></span>
                  <span className="profile-dropdown-text">
                    <span className="profile-dropdown-item-title">{l.title}</span>
                    <span className="profile-dropdown-item-desc">{l.desc}</span>
                  </span>
                </Link>
              ))}
            </div>
            <div className="profile-dropdown-footer">
              <Link
                to="/vida-plus"
                className="profile-dive-deeper"
                onClick={() => setOpen(false)}
              >
                <Sparkles size={15} strokeWidth={1.5} />
                Dive deeper
              </Link>
              <button className="profile-signout" onClick={handleLogout}>
                <LogOut size={15} strokeWidth={1.5} />
                Sign out
              </button>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}