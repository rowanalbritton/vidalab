import React from "react";
import { Link } from "react-router-dom";

export default function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="wrap">
        <div className="footer-grid">
          <div>
            <Link className="brand" to="/">
              <img src="https://media.base44.com/images/public/6aacae7dbd22557932ef6597/6c7aef48d_Screenshot2026-09-17at34708AM.png" alt="VIDA LAB" style={{ height: 52, width: "auto", display: "block", borderRadius: 12 }} />
            </Link>
            <p>Clear, careful explanations of what is changing in medicine. Educational information and wellness reflection, never medical advice.</p>
          </div>
          <div className="footer-links">
            <strong>Explore</strong>
            <Link to="/research">Research</Link>
            <Link to="/research#conditions">Conditions</Link>
            <Link to="/research#technology">Technology</Link>
            <Link to="/app">App</Link>
          </div>
          <div className="footer-links">
            <strong>VIDA LAB</strong>
            <Link to="/about">About</Link>
            <Link to="/rowans-work">Rowan's Work</Link>
            <Link to="/privacy">Privacy</Link>
            <Link to="/terms">Terms</Link>
            <a href="https://vidalab.substack.com" target="_blank" rel="noopener noreferrer">Substack</a>
            <a href="https://youtube.com/@thevidalab" target="_blank" rel="noopener noreferrer">YouTube</a>
          </div>
        </div>
        <div className="footer-bottom" style={{ display: "block" }}>
          <p style={{ fontSize: 12, color: "var(--taupe)", maxWidth: 760, marginBottom: 14, lineHeight: 1.6 }}>
            <strong style={{ color: "var(--soft)" }}>Medical disclaimer:</strong> VIDA LAB is an educational science-communication platform. The founder is a student researcher, not a licensed medical doctor or healthcare provider. Nothing on this site is medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional before making decisions about your health.
          </p>
          <div style={{ display: "flex", justifyContent: "space-between" }}>
            <span>© 2026 VIDA LAB</span>
            <span>Research evolves. Our explanations do too.</span>
          </div>
        </div>
      </div>
    </footer>
  );
}