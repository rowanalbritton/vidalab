import React from "react";

export default class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error("ErrorBoundary caught:", error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{ minHeight: "100vh", display: "flex", alignItems: "center", justifyContent: "center", padding: "2rem", background: "#F9F8F5" }}>
          <div style={{ maxWidth: "480px", textAlign: "center" }}>
            <h2 style={{ fontFamily: "Georgia, serif", fontSize: "1.75rem", color: "#2E463E", marginBottom: "0.75rem" }}>
              Something went wrong
            </h2>
            <p style={{ color: "#5a655e", fontSize: "0.95rem", lineHeight: 1.6, marginBottom: "1.5rem" }}>
              The app encountered an unexpected error. Try reloading the page.
            </p>
            <button
              onClick={() => window.location.reload()}
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: "0.5rem",
                padding: "0.75rem 1.5rem",
                borderRadius: "9999px",
                background: "#2E463E",
                color: "#F9F8F5",
                border: "none",
                fontSize: "0.875rem",
                fontWeight: 500,
                cursor: "pointer",
              }}
            >
              Reload page
            </button>
            {this.state.error && (
              <pre style={{ marginTop: "1.5rem", padding: "1rem", background: "#fff", border: "1px solid #E8E5DF", borderRadius: "12px", fontSize: "0.75rem", color: "#5a655e", textAlign: "left", overflow: "auto", maxHeight: "200px" }}>
                {this.state.error.message}
              </pre>
            )}
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}