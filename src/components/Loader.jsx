import React from "react";

export default function Loader({ label, className }) {
  return (
    <div className={`flex flex-col items-center justify-center gap-4 ${className || ""}`}>
      <div className="relative w-14 h-14">
        {/* Outer ring — spins clockwise */}
        <div
          className="absolute inset-0 rounded-full animate-spin"
          style={{
            borderWidth: "2px",
            borderStyle: "solid",
            borderColor: "hsl(var(--border))",
            borderTopColor: "hsl(var(--primary))",
            animationDuration: "1.2s",
          }}
        />
        {/* Inner ring — spins counter-clockwise */}
        <div
          className="absolute inset-[6px] rounded-full animate-spin"
          style={{
            borderWidth: "1.5px",
            borderStyle: "solid",
            borderColor: "transparent",
            borderBottomColor: "#3c6b4f",
            borderRightColor: "#87C0E4",
            animationDuration: "1.8s",
            animationDirection: "reverse",
          }}
        />
        {/* Pulsing center dot */}
        <div className="absolute inset-0 flex items-center justify-center">
          <div
            className="w-2 h-2 rounded-full animate-pulse"
            style={{ backgroundColor: "hsl(var(--primary))" }}
          />
        </div>
      </div>
      {label && <p className="text-sm text-muted-foreground">{label}</p>}
    </div>
  );
}