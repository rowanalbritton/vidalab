import React from "react";
import { termsContent } from "@/data/legalContent";

export default function Terms() {
  return (
    <main className="wrap" dangerouslySetInnerHTML={{ __html: termsContent }} />
  );
}