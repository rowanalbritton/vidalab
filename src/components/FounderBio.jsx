import React from "react";
import { Image } from "@/components/ui/image";

const FOUNDER_IMAGE =
  "https://media.base44.com/images/public/6aacae7dbd22557932ef6597/2f21574c2_IMG_3188.jpeg";
const LINKEDIN_URL = "https://www.linkedin.com/in/rowanalbritton";

function LinkedinIcon({ className }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="currentColor"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.063 2.063 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
    </svg>
  );
}

export default function FounderBio() {
  return (
    <section
      style={{
        background: "var(--paper)",
        borderTop: "1px solid var(--line)",
        borderBottom: "1px solid var(--line)",
      }}
    >
      <div className="wrap" style={{ padding: "90px 0" }}>
        <div className="founder-grid">
          {/* Portrait — fills the former blank space */}
          <div className="founder-portrait-wrap">
            <Image
              src={FOUNDER_IMAGE}
              alt="Rowan Albritton, founder of Vida Lab"
              className="founder-portrait"
              fittingType="fill"
              focalPointX={0.4}
              focalPointY={0.62}
            />
          </div>

          {/* Bio + LinkedIn */}
          <div className="founder-content">
            <div className="eyebrow">About the founder</div>
            <h2 className="founder-name">Rowan Albritton</h2>

            <div className="prose founder-prose">
              <p>
                Hi — I'm Rowan. I'm 18, and I started Vida Lab in May 2023.
              </p>

              <h3>Why I started Vida Lab</h3>
              <p>
                For years, I struggled with health issues that no one really
                explained. I'd leave appointments with more questions than
                answers, and I kept wishing someone had handed me the tools, the
                language, and the confidence to understand what was happening
                in my own body. It took a long time to get a name —
                endometriosis — and even longer to feel like I had the words to
                talk about it. The gap between what I was living and what I
                could find in the research felt huge.
              </p>
              <p>
                So I built the thing I wished I'd had. Vida Lab is me sitting
                down with scientific studies and translating them into language
                that actually makes sense. Right now I'm taking courses in
                MATLAB and Python to strengthen the data and computational side
                of how I read and translate research. I've written research
                papers on Alzheimer's prevention, CRISPR germline editing, and
                workplace burnout. I've talked with people living with chronic
                illness and I write a weekly newsletter about recovery and
                learning.
              </p>
              <p>
                Mostly I just want to be in the corner of anyone going through
                the same confusing, lonely health stuff I went through —
                especially young people with conditions that are chronic,
                misunderstood, or too easily brushed off. You shouldn't have to
                figure it out by yourself.
              </p>
              <p>
                Vida Lab doesn't diagnose anyone or tell you what your body
                should be doing. It gives you enough understanding to notice your
                own patterns and walk into your next appointment with better
                questions.{" "}
                <em>Where real stories meet real science.</em>
              </p>
              <p>
                Come explore the condition library, or subscribe to the weekly
                newsletter — that's where the newest research and my latest
                reflections show up first.
              </p>
            </div>

            <a
              href={LINKEDIN_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="button linkedin-button"
            >
              <LinkedinIcon className="w-4 h-4" />
              Connect on LinkedIn
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}