import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate } from "remotion";
import { Mascot, ambientPose } from "../Mascot";
import { MenuBar } from "./SceneDancing";

const STORY_LINES = [
  "I've been building with",
  "Claude Code since the day",
  "it launched.",
  "",
  "Now I'm shipping a company",
  "in 2-3 weeks.",
  "",
  "And he's coming along",
  "for the ride.",
];

export const SceneStory: React.FC<{ startFrame: number }> = ({ startFrame }) => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();

  const localFrame = frame - startFrame;
  const t = localFrame / fps;
  const barHeight = 44;
  const mascotSize = 56;

  // 7s = 210 frames
  // Lines appear staggered
  const lineFps = 210 / (STORY_LINES.filter(Boolean).length + 1);

  let lineIndex = 0;
  const visibleLines = STORY_LINES.map((line, i) => {
    if (!line) return { line: "", opacity: 0, delay: 0 };
    const delay = lineIndex * lineFps;
    lineIndex++;
    const opacity = interpolate(localFrame, [delay, delay + 15], [0, 1], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    return { line, opacity, delay };
  });

  const ambient = ambientPose(t, 185);

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background: "radial-gradient(ellipse at 50% 60%, #1a1a2e 0%, #0a0a0a 70%)",
        display: "flex",
        flexDirection: "column",
        position: "relative",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "radial-gradient(circle, rgba(255,119,0,0.06) 1px, transparent 1px)",
          backgroundSize: "40px 40px",
        }}
      />

      <MenuBar width={width} />

      {/* Mascot - idle left seat */}
      <div
        style={{
          position: "absolute",
          top: barHeight - 4,
          left: "50%",
          transform: `translateX(calc(-50% + ${ambient.x ?? 0}px))`,
          zIndex: 20,
        }}
      >
        <Mascot
          pose={{
            y: ambient.y ?? 0,
            rotation: ambient.rotation ?? 0,
            scale: ambient.scale ?? 1,
          }}
          size={mascotSize}
        />
      </div>

      {/* Story text */}
      <div
        style={{
          position: "absolute",
          top: "50%",
          left: 0,
          right: 0,
          transform: "translateY(-50%)",
          padding: "0 60px",
          textAlign: "center",
        }}
      >
        {visibleLines.map(({ line, opacity }, i) => (
          <p
            key={i}
            style={{
              fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
              fontSize: line.includes("2-3 weeks") ? 42 : 36,
              fontWeight: line.includes("launched") || line.includes("2-3 weeks") ? 700 : 400,
              color: line.includes("2-3 weeks")
                ? "#FF7700"
                : line.includes("he's coming")
                ? "#FF7700"
                : "#ffffff",
              margin: line ? "4px 0" : "12px 0",
              opacity,
              lineHeight: 1.3,
              minHeight: line ? "auto" : 12,
            }}
          >
            {line}
          </p>
        ))}
      </div>
    </div>
  );
};
