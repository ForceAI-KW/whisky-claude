import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate } from "remotion";
import { Mascot, ambientPose } from "../Mascot";

export const SceneCTA: React.FC<{ startFrame: number }> = ({ startFrame }) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();

  const localFrame = frame - startFrame;
  const t = localFrame / fps;

  // Title appears
  const titleOpacity = interpolate(localFrame, [0, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const titleY = interpolate(localFrame, [0, 20], [30, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Tagline appears
  const tagOpacity = interpolate(localFrame, [15, 35], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // GitHub URL appears
  const githubOpacity = interpolate(localFrame, [30, 50], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Force AI bar at bottom
  const barOpacity = interpolate(localFrame, [40, 60], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Mascot idle
  const ambient = ambientPose(t, 80);

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        backgroundColor: "#000000",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        position: "relative",
        overflow: "hidden",
      }}
    >
      {/* Subtle background glow */}
      <div
        style={{
          position: "absolute",
          top: "30%",
          left: "50%",
          transform: "translate(-50%, -50%)",
          width: 500,
          height: 500,
          borderRadius: "50%",
          background: "radial-gradient(circle, rgba(255,119,0,0.08) 0%, transparent 70%)",
          pointerEvents: "none",
        }}
      />

      {/* Main content */}
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 0,
          flex: 1,
          justifyContent: "center",
          paddingBottom: 100,
        }}
      >
        {/* Mascot */}
        <div
          style={{
            marginBottom: 32,
            opacity: titleOpacity,
          }}
        >
          <Mascot
            pose={{
              y: ambient.y ?? 0,
              rotation: ambient.rotation ?? 0,
              scale: (ambient.scale ?? 1) * 1.5,
            }}
            size={96}
          />
        </div>

        {/* Title */}
        <div
          style={{
            opacity: titleOpacity,
            transform: `translateY(${titleY}px)`,
            textAlign: "center",
          }}
        >
          <p
            style={{
              fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', 'SF Pro Display', sans-serif",
              fontSize: 88,
              fontWeight: 800,
              color: "#ffffff",
              margin: 0,
              letterSpacing: "-0.03em",
              lineHeight: 1,
            }}
          >
            Whisky
          </p>
          <p
            style={{
              fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', 'SF Pro Display', sans-serif",
              fontSize: 88,
              fontWeight: 800,
              color: "#FF7700",
              margin: "4px 0 0",
              letterSpacing: "-0.03em",
              lineHeight: 1,
            }}
          >
            Claude
          </p>
        </div>

        {/* Tagline */}
        <div
          style={{
            opacity: tagOpacity,
            marginTop: 32,
            textAlign: "center",
          }}
        >
          <p
            style={{
              fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
              fontSize: 32,
              fontWeight: 400,
              color: "rgba(255,255,255,0.7)",
              margin: 0,
              letterSpacing: "0.02em",
            }}
          >
            Free. Open source. Fully on-device.
          </p>
        </div>

        {/* GitHub URL */}
        <div
          style={{
            opacity: githubOpacity,
            marginTop: 28,
            backgroundColor: "rgba(255,119,0,0.1)",
            border: "1.5px solid rgba(255,119,0,0.4)",
            borderRadius: 12,
            padding: "14px 28px",
          }}
        >
          <p
            style={{
              fontFamily: "'SF Mono', 'Fira Code', 'Cascadia Code', monospace",
              fontSize: 26,
              fontWeight: 500,
              color: "#FF7700",
              margin: 0,
              letterSpacing: "0.01em",
            }}
          >
            github.com/ForceAI-KW/whisky-claude
          </p>
        </div>
      </div>

      {/* Force AI bar */}
      <div
        style={{
          position: "absolute",
          bottom: 0,
          left: 0,
          right: 0,
          height: 72,
          backgroundColor: "#FF7700",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 16,
          opacity: barOpacity,
        }}
      >
        {/* Force AI logo mark — stylized F */}
        <div
          style={{
            width: 36,
            height: 36,
            borderRadius: 8,
            backgroundColor: "rgba(0,0,0,0.2)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <span
            style={{
              fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
              fontSize: 22,
              fontWeight: 900,
              color: "#ffffff",
            }}
          >
            F
          </span>
        </div>
        <p
          style={{
            fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
            fontSize: 24,
            fontWeight: 700,
            color: "#ffffff",
            margin: 0,
            letterSpacing: "0.04em",
          }}
        >
          FORCE AI
        </p>
      </div>
    </div>
  );
};
