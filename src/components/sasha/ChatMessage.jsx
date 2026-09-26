import React from "react";
import ReactMarkdown from "react-markdown";

export default function ChatMessage({ message }) {
  const isUser = message.role === "user";
  if (!message.content) return null;

  return (
    <div style={{ display: "flex", justifyContent: isUser ? "flex-end" : "flex-start", marginBottom: 14 }}>
      <div
        style={{
          maxWidth: "80%",
          padding: "12px 17px",
          borderRadius: 18,
          background: isUser ? "var(--forest)" : "var(--cream)",
          color: isUser ? "var(--cream)" : "var(--ink)",
          fontSize: 14,
          lineHeight: 1.6,
        }}
      >
        {isUser ? message.content : <ReactMarkdown>{message.content}</ReactMarkdown>}
      </div>
    </div>
  );
}