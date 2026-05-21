import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate } from "remotion";
import { Mascot, ambientPose } from "../Mascot";

// Notch bar used across scenes
export const MenuBar: React.FC<{ width: number; barHeight?: number }> = ({
  width,
  barHeight = 44,
}) => {
  const notchW = 185;
  const notchH = 34;

  return (
    <div
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        width: "100%",
        height: barHeight,
        backgroundColor: "#0a0a0a",
      }}
    >
      {/* Notch cutout */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: "50%",
          transform: "translateX(-50%)",
          width: notchW,
          height: notchH,
          borderRadius: "0 0 12px 12px",
          backgroundColor: "#000000",
          boxShadow: "0 0 0 1px rgba(255,255,255,0.05)",
        }}
      />
      {/* Menu bar right items */}
      <div
        style={{
          position: "absolute",
          top: 0,
          right: 24,
          height: barHeight,
          display: "flex",
          alignItems: "center",
          gap: 14,
          opacity: 0.4,
        }}
      >
        {[52, 20, 20, 16].map((w, i) => (
          <div
            key={i}
            style={{
              width: w,
              height: 10,
              borderRadius: 3,
              backgroundColor: "rgba(255,255,255,0.6)",
            }}
          />
        ))}
      </div>
      {/* Left apple logo */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 20,
          height: barHeight,
          display: "flex",
          alignItems: "center",
          opacity: 0.4,
        }}
      >
        <div
          style={{
            width: 14,
            height: 16,
            borderRadius: "50% 50% 50% 50% / 40% 40% 60% 60%",
            backgroundColor: "rgba(255,255,255,0.6)",
          }}
        />
      </div>
    </div>
  );
};

export const SceneDancing: React.FC<{ startFrame: number }> = ({ startFrame }) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();

  const localFrame = frame - startFrame;
  const t = localFrame / fps;
  const barHeight = 44;
  const seatOffset = -185;
  const mascotSize = 64;

  // Ambient dancing (starts left seat)
  const pose = ambientPose(t, 185);

  // Walk from left to right around frame 120 (4s into scene)
  // Scene is 7s (210 frames). Walk starts at frame 120.
  const walkStartLocal = 120;
  const walkDuration = 60; // 2s walk
  const isWalking = localFrame >= walkStartLocal && localFrame < walkStartLocal + walkDuration;
  const walkProgress = isWalking
    ? (localFrame - walkStartLocal) / walkDuration
    : localFrame >= walkStartLocal + walkDuration
    ? 1
    : 0;

  const smoothWalk = walkProgress * walkProgress * (3 - 2 * walkProgress);
  const leftSeat = -185;
  const rightSeat = 185;
  const walkX = leftSeat + (rightSeat - leftSeat) * smoothWalk;

  const currentX = isWalking
    ? walkX
    : localFrame >= walkStartLocal + walkDuration
    ? rightSeat + (pose.x ?? 0) - 185 // dancing at right side
    : (pose.x ?? 0);

  const currentRotation = isWalking
    ? 5 * (walkProgress < 0.5 ? 1 : -1)
    : pose.rotation ?? 0;

  // Footstep during walk
  const stepPhase = (t * 1.6) % 1.0;
  const footstep = isWalking && stepPhase < 0.35
    ? Math.sin((stepPhase / 0.35) * Math.PI) * 2.0
    : 0;

  // Caption timing
  const caption1Opacity = interpolate(localFrame, [10, 40], [0, 1], {
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

      <MenuBar width={width} />

      {/* Mascot */}
      <div
        style={{
          position: "absolute",
          top: barHeight - 4,
          left: "50%",
          transform: `translateX(calc(-50% + ${currentX}px))`,
          zIndex: 20,
        }}
      >
        <Mascot
          pose={{
            y: footstep + (pose.y ?? 0),
            rotation: currentRotation,
            scale: pose.scale ?? 1,
          }}
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
          opacity: caption1Opacity,
        }}
      >
        <p
          style={{
            fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
            fontSize: 38,
            fontWeight: 600,
            color: "#ffffff",
            margin: 0,
            lineHeight: 1.4,
            textShadow: "0 2px 16px rgba(0,0,0,0.9)",
          }}
        >
          He lives beside the notch.{" "}
          <span style={{ color: "#FF7700" }}>Walks. Dances. Just exists.</span>
        </p>
      </div>
    </div>
  );
};
