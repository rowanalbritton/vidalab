import React, { useState } from "react";
import { base44 } from "@/api/base44Client";

export default function NewsletterForm() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email) return;
    setStatus("Joining…");
    try {
      const res = await base44.functions.invoke("newsletter-signup", { email });
      setStatus(res.data.message || "You're in. Stay curious.");
      setEmail("");
    } catch {
      setStatus("That didn't go through. Please try again.");
    }
  };

  return (
    <div>
      <form className="newsletter-form" onSubmit={handleSubmit}>
        <input type="hidden" name="form-name" value="vida-lab-newsletter" />
        <label htmlFor="nl-email" hidden>Email address</label>
        <input
          id="nl-email"
          type="email"
          name="email"
          required
          placeholder="Your email address"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <button type="submit">Join VIDA LAB →</button>
      </form>
      <p className="form-status" aria-live="polite">{status}</p>
      <p className="form-note">Thoughtful updates, not a flood. Unsubscribe anytime.</p>
    </div>
  );
}