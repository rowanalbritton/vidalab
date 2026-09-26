import React from "react";
import { privacyContent } from "@/data/legalContent";

export default function Privacy() {
  return (
    <main className="wrap" dangerouslySetInnerHTML={{ __html: privacyContent }} />
  );
}