import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate } from "remotion";
import { Mascot, ambientPose, attentionPose } from "../Mascot";
import { MenuBar } from "./SceneDancing";

// Waveform pulsing icon
const Waveform: React.FC<{ pulse: number; opacity: number }> = ({ pulse, opacity }) => {
  const bars = [0.4, 0.7, 1.0, 0.7, 0.4, 0.9, 0.6, 1.0, 0.5, 0.8];
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 3,
        opacity,
        height: 36,
      }}
    >
      {bars.map((h, i) => {
        const animatedH = h * (1 + Math.sin(pulse * Math.PI * 2 + i * 0.6) * 0.3);
        return (
          <div
            key={i}
            style={{
              width: 4,
              height: 36 * animatedH,
              borderRadius: 2,
              backgroundColor: "#FF7700",
              transition: "height 0.05s ease",
            }}
          />
        );
      })}
    </div>
  );
};

export const SceneAttention: React.FC<{ startFrame: number }> = ({ startFrame }) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();

  const localFrame = frame - startFrame;
  const t = localFrame / fps;
  const barHeight = 44;
  const mascotSize = 64;

  // Ambient idle right seat
  const ambient = ambientPose(t + 68, 185); // Start from "right seat" phase offset

  // Attention animation: starts at frame 30 (1s in), lasts ~1s = 30 frames
  const attentionStart = 30;
  const attentionDuration = 35;
  const isInAttention =
    localFrame >= attentionStart && localFrame < attentionStart + attentionDuration;
  const attentionProgress = isInAttention
    ? (localFrame - attentionStart) / attentionDuration
    : localFrame >= attentionStart + attentionDuration
    ? 1.0
    : 0;

  const bounce = attentionProgress > 0 ? attentionPose(attentionProgress) : {};

  const finalX = ambient.x ?? 0;
  const finalY = (ambient.y ?? 0) + (bounce.y ?? 0);
  const finalRotation = (ambient.rotation ?? 0) + (bounce.rotation ?? 0);
  const finalScale = (ambient.scale ?? 1) * (bounce.scale ?? 1);

  // Caption 1: "When Claude Code needs you…"
  const caption1Opacity = interpolate(localFrame, [0, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  // Caption fades out at frame 25
  const caption1FadeOut = interpolate(localFrame, [25, 35], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Waveform appears
  const waveOpacity = interpolate(localFrame, [28, 50], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const wavePulse = t * 2;

  // Big flash on attention trigger
  const flashOpacity = interpolate(localFrame, [30, 32, 36], [0, 0.15, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

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
      {/* Background dots */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "radial-gradient(circle, rgba(255,119,0,0.06) 1px, transparent 1px)",
          backgroundSize: "40px 40px",
        }}
      />

      {/* Flash overlay */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundColor: "#FF7700",
          opacity: flashOpacity,
          zIndex: 50,
          pointerEvents: "none",
        }}
      />

      <MenuBar width={width} />

      {/* Waveform above mascot */}
      <div
        style={{
          position: "absolute",
          top: barHeight + 10,
          left: "50%",
          transform: `translateX(calc(-50% + ${finalX}px))`,
          zIndex: 15,
        }}
      >
        <Waveform pulse={wavePulse} opacity={waveOpacity} />
      </div>

      {/* Mascot */}
      <div
        style={{
          position: "absolute",
          top: barHeight - 4,
          left: "50%",
          transform: `translateX(calc(-50% + ${finalX}px))`,
          zIndex: 20,
        }}
      >
        <Mascot
          pose={{ y: finalY, rotation: finalRotation, scale: finalScale }}
          size={mascotSize}
        />
      </div>

      {/* Caption */}
      <div
        style={{
          position: "absolute",
          bottom: 100,
          left: 0,
          right: 0,
          padding: "0 50px",
          textAlign: "center",
          opacity: caption1Opacity * caption1FadeOut,
        }}
      >
        <p
          style={{
            fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
            fontSize: 42,
            fontWeight: 600,
            color: "#ffffff",
            margin: 0,
            textShadow: "0 2px 16px rgba(0,0,0,0.9)",
          }}
        >
          When Claude Code{" "}
          <span style={{ color: "#FF7700" }}>needs you…</span>
        </p>
      </div>
    </div>
  );
};
