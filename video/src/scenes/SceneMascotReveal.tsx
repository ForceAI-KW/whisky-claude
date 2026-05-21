import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate, spring } from "remotion";
import { Mascot, ambientPose } from "../Mascot";

// Notch shape SVG – M-series MacBook notch approximation
const NotchShape: React.FC<{ barHeight: number }> = ({ barHeight }) => {
  // Notch is ~185px wide, 34px tall at the top
  const notchW = 185;
  const notchH = 34;
  return (
    <svg
      style={{ position: "absolute", top: 0, left: 0, width: "100%", height: barHeight }}
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* Full menu bar background */}
      <rect x={0} y={0} width="100%" height={barHeight} fill="#0a0a0a" />
      {/* Notch cutout — black rounded rect in center */}
      <rect
        x={`calc(50% - ${notchW / 2}px)`}
        y={0}
        width={notchW}
        height={notchH}
        rx={10}
        ry={10}
        fill="#000000"
      />
    </svg>
  );
};

export const SceneMascotReveal: React.FC<{ startFrame: number }> = ({ startFrame }) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();

  // This scene: frames 0 to 150 (5s) within its own offset
  // But we receive the global frame and startFrame
  const localFrame = frame - startFrame;

  // Bar slides in from top
  const barHeight = 44;
  const barY = interpolate(localFrame, [0, 20], [-barHeight, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Mascot walks in from left
  // Mascot should sit left of notch. Notch center = width/2 = 540
  // Seat left = center - notchWidth/2 - seatGap - mascotSize/2 = 540 - 92.5 - 50 - 32 = ~365
  // For video, scale up: seat offset from center ~ -185px
  const seatOffsetX = -185;
  const mascotSize = 64;

  const walkInProgress = interpolate(localFrame, [10, 70], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Start far left (-width/2 - mascotSize), end at seat
  const startX = -width / 2 - mascotSize;
  const endX = seatOffsetX;
  const mascotX = startX + (endX - startX) * (walkInProgress < 1 ? walkInProgress * walkInProgress * (3 - 2 * walkInProgress) : 1);

  // After arriving, do ambient dance
  const t = Math.max(0, (localFrame - 70)) / fps;
  const ambient = walkInProgress >= 1 ? ambientPose(t, 185) : { x: 0, y: 0, rotation: 0, scale: 1 };

  const finalX = walkInProgress >= 1 ? (ambient.x ?? 0) : mascotX;
  const lean = walkInProgress < 1 ? 5 : (ambient.rotation ?? 0);

  // Background desktop gradient
  const bgOpacity = interpolate(localFrame, [0, 30], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Caption fade in
  const captionOpacity = interpolate(localFrame, [80, 110], [0, 1], {
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
        alignItems: "center",
        justifyContent: "center",
        position: "relative",
        overflow: "hidden",
        opacity: bgOpacity,
      }}
    >
      {/* Simulated desktop grid dots */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage:
            "radial-gradient(circle, rgba(255,119,0,0.08) 1px, transparent 1px)",
          backgroundSize: "40px 40px",
          opacity: 0.6,
        }}
      />

      {/* Menu bar with notch */}
      <div
        style={{
          position: "absolute",
          top: barY,
          left: 0,
          width: "100%",
          height: barHeight,
          zIndex: 10,
        }}
      >
        <NotchShape barHeight={barHeight} />
        {/* Menu bar items hint */}
        <div
          style={{
            position: "absolute",
            top: 0,
            right: 20,
            height: barHeight,
            display: "flex",
            alignItems: "center",
            gap: 16,
            opacity: 0.5,
          }}
        >
          {["wifi", "battery", "time"].map((item) => (
            <div
              key={item}
              style={{
                width: item === "time" ? 50 : 20,
                height: 12,
                borderRadius: 3,
                backgroundColor: "rgba(255,255,255,0.3)",
              }}
            />
          ))}
        </div>
      </div>

      {/* Mascot positioned near menu bar */}
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
          pose={{ y: ambient.y ?? 0, rotation: lean, scale: ambient.scale ?? 1 }}
          size={mascotSize}
          opacity={walkInProgress > 0.05 ? 1 : 0}
        />
      </div>

      {/* Caption */}
      <div
        style={{
          position: "absolute",
          bottom: 80,
          left: 0,
          right: 0,
          textAlign: "center",
          opacity: captionOpacity,
          padding: "0 40px",
        }}
      >
        <p
          style={{
            fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
            fontSize: 36,
            fontWeight: 600,
            color: "#ffffff",
            margin: 0,
            textShadow: "0 2px 12px rgba(0,0,0,0.8)",
          }}
        >
          Meet{" "}
          <span style={{ color: "#FF7700" }}>Whisky Claude</span>
        </p>
      </div>
    </div>
  );
};
