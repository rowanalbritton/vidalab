import React, { useEffect, useRef, useState } from "react";
import { supabase } from "@/lib/supabaseClient";
import ChatMessage from "@/components/sasha/ChatMessage";
import MembershipGate from "@/components/MembershipGate";
import Loader from "@/components/Loader";
import { Send, Loader2 } from "lucide-react";

export default function Sasha() {
  const [accessChecked, setAccessChecked] = useState(false);
  const [isVidaPlus, setIsVidaPlus] = useState(false);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const bottomRef = useRef(null);

  // Server-side Vida+ check. The vida-chat function re-checks membership on
  // every message too, so this only decides which screen to show.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const { data } = await supabase.functions.invoke("vida-chat", { body: { check: true } });
        if (!cancelled && data?.allowed) {
          setIsVidaPlus(true);
          setAccessChecked(true);
        } else if (!cancelled) {
          setIsVidaPlus(false);
          setAccessChecked(true);
        }
      } catch (_) {
        if (!cancelled) {
          setIsVidaPlus(false);
          setAccessChecked(true);
        }
      }
    })();
    return () => { cancelled = true; };
  }, []);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: "smooth" }); }, [messages]);

  if (!accessChecked) {
    return (
      <main className="wrap" style={{ padding: "120px 0", display: "flex", justifyContent: "center" }}>
        <Loader />
      </main>
    );
  }

  if (!isVidaPlus) {
    return (
      <MembershipGate title="Ask Vida is a Vida+ feature">
        Vida is your AI health companion — she listens, helps you think through symptoms and research, and points you toward VIDA LAB explainers. Upgrade to Vida+ to start your conversation.
      </MembershipGate>
    );
  }

  const handleSend = async (e) => {
    e.preventDefault();
    if (!input.trim() || sending) return;
    setSending(true);
    const text = input.trim();
    setInput("");
    // The conversation lives only in this tab. The whole history goes up with
    // each message because the function keeps nothing between calls.
    const history = [...messages, { role: "user", content: text }];
    setMessages(history);
    try {
      const { data, error } = await supabase.functions.invoke("vida-chat", { body: { messages: history } });
      if (error || !data?.reply) throw error || new Error(data?.error || "No reply");
      setMessages([...history, { role: "assistant", content: data.reply }]);
    } catch (e) {
      console.error(e);
      // Put the message back so nothing typed is lost, and drop it from the
      // transcript so the next send doesn't carry two user turns in a row.
      setMessages(messages);
      setInput(text);
    }
    setSending(false);
  };

  return (
    <main className="wrap" style={{ padding: "60px 0 90px", maxWidth: 720 }}>
      <div className="eyebrow">Talk to Vida</div>
      <h1 style={{ fontSize: "clamp(36px,5vw,52px)", margin: "14px 0 18px" }}>A companion for chronic illness &amp; health questions.</h1>
      <p style={{ color: "var(--soft)", fontSize: 17, marginBottom: 34, maxWidth: 600 }}>
        Vida is an AI guide, not a doctor. She's here to listen, help you think through symptoms and research, and point you toward VIDA LAB explainers — never to diagnose or replace medical care.
      </p>

      <div style={{ border: "1px solid var(--line)", borderRadius: "var(--radius)", background: "var(--paper)", display: "flex", flexDirection: "column", height: "min(540px, 60vh)" }}>
        <div style={{ flex: 1, overflowY: "auto", padding: "min(26px, 16px)" }}>
          {messages.length === 0 && (
            <p style={{ color: "var(--soft)", fontSize: 14 }}>Say hello to Vida — ask about a symptom, a condition, or something from the research.</p>
          )}
          {messages.map((m, i) => <ChatMessage key={i} message={m} />)}
          <div ref={bottomRef} />
        </div>
        <form onSubmit={handleSend} style={{ display: "flex", gap: 10, borderTop: "1px solid var(--line)", padding: 16 }}>
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="Type your message..."
            style={{ flex: 1, border: "1px solid var(--line)", borderRadius: 100, padding: "12px 18px", outline: "none", background: "var(--cream)", color: "var(--ink)" }}
          />
          <button type="submit" disabled={sending || !input.trim()} className="button" style={{ padding: "0 22px" }}>
            {sending ? <Loader2 size={16} className="animate-spin" /> : <Send size={16} />}
          </button>
        </form>
      </div>
    </main>
  );
}