import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate, spring } from "remotion";

const WORDS = ["I", "built", "a", "desktop", "pet", "for", "Claude", "Code."];

export const SceneHook: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // 3 seconds = 90 frames. Words appear staggered.
  const totalFrames = 90;
  const wordDelay = totalFrames / (WORDS.length + 1);

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        backgroundColor: "#000000",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: "60px",
      }}
    >
      <p
        style={{
          fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', 'SF Pro Display', sans-serif",
          fontSize: 72,
          fontWeight: 700,
          color: "#ffffff",
          textAlign: "center",
          lineHeight: 1.15,
          letterSpacing: "-0.02em",
          margin: 0,
        }}
      >
        {WORDS.map((word, i) => {
          const wordFrame = i * wordDelay;
          const opacity = interpolate(frame, [wordFrame, wordFrame + 8], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          const translateY = interpolate(frame, [wordFrame, wordFrame + 10], [20, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });
          return (
            <span
              key={i}
              style={{
                display: "inline",
                opacity,
                transform: `translateY(${translateY}px)`,
                marginRight: word === "." ? 0 : "0.28em",
                // Accent "Claude Code" orange
                color: word === "Claude" || word === "Code." ? "#FF7700" : "#ffffff",
              }}
            >
              {word}{" "}
            </span>
          );
        })}
      </p>
    </div>
  );
};
