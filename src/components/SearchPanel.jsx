import React, { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { FEATURES } from "@/data/features";

const STATIC_PAGES = [
  { name: "Migraine research", url: "/conditions/migraine" },
  { name: "POTS research", url: "/conditions/pots" },
  { name: "Long COVID research", url: "/conditions/long-covid" },
  { name: "Fibromyalgia research", url: "/conditions/fibromyalgia" },
  { name: "Research Explorer", url: "/research" },
  { name: "VIDA LAB App", url: "/app" },
  { name: "About VIDA LAB", url: "/about" },
  { name: "Support", url: "/support" },
  { name: "Privacy Policy", url: "/privacy" },
  { name: "Terms of Use", url: "/terms" },
];

const SEARCH_ENTRIES = [
  ...FEATURES.map((f) => ({ name: f.title, url: f.path, plus: !!f.plus })),
  ...STATIC_PAGES,
];

export default function SearchPanel({ open, onClose }) {
  const [query, setQuery] = useState("");
  const inputRef = useRef(null);
  const navigate = useNavigate();

  useEffect(() => {
    if (open) {
      setQuery("");
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  }, [open]);

  useEffect(() => {
    const onKey = (e) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const results = query
    ? SEARCH_ENTRIES.filter((e) => e.name.toLowerCase().includes(query.toLowerCase()))
    : SEARCH_ENTRIES;

  const go = (url) => { onClose(); navigate(url); };

  if (!open) return null;

  return (
    <div className="search-panel open" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="search-box">
        <div className="eyebrow">Search VIDA LAB</div>
        <input
          ref={inputRef}
          type="search"
          placeholder="Try concierge, doctor finder, migraine…"
          aria-label="Search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        <div className="search-results">
          {results.length ? results.map((e) => (
            <a key={e.url} href={e.url} onClick={(ev) => { ev.preventDefault(); go(e.url); }}>
              {e.name} {e.plus && <span className="search-badge">Vida+</span>} →
            </a>
          )) : <span style={{ color: "var(--soft)", padding: 10 }}>No matching VIDA LAB pages yet.</span>}
        </div>
      </div>
    </div>
  );
}