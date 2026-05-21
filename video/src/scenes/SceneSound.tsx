import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate } from "remotion";
import { Mascot, ambientPose, donePose } from "../Mascot";
import { MenuBar } from "./SceneDancing";

// Waveform bar
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
            }}
          />
        );
      })}
    </div>
  );
};

// Typed text animation (character by character)
const TypedText: React.FC<{ text: string; startFrame: number; charsPerFrame?: number }> = ({
  text,
  startFrame,
  charsPerFrame = 0.5,
}) => {
  const frame = useCurrentFrame();
  const charsToShow = Math.floor((frame - startFrame) * charsPerFrame);
  const visible = text.slice(0, Math.max(0, charsToShow));

  return (
    <span>
      {visible}
      {charsToShow < text.length && charsToShow >= 0 && (
        <span style={{ opacity: Math.sin((frame - startFrame) * 0.5) > 0 ? 1 : 0 }}>|</span>
      )}
    </span>
  );
};

export const SceneSound: React.FC<{ startFrame: number }> = ({ startFrame }) => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();

  const localFrame = frame - startFrame;
  const t = localFrame / fps;
  const barHeight = 44;
  const mascotSize = 64;

  // Idle at right seat
  const ambient = ambientPose(t + 68, 185);

  // Done bounce at frame 10 (0.3s in)
  const doneStart = 10;
  const doneDuration = 30;
  const isInDone = localFrame >= doneStart && localFrame < doneStart + doneDuration;
  const doneProgress = isInDone
    ? (localFrame - doneStart) / doneDuration
    : localFrame >= doneStart + doneDuration
    ? 1.0
    : 0;

  const bounce = doneProgress > 0 ? donePose(doneProgress) : {};

  const finalX = ambient.x ?? 0;
  const finalY = (ambient.y ?? 0) + (bounce.y ?? 0);
  const finalRotation = (ambient.rotation ?? 0) + (bounce.rotation ?? 0);
  const finalScale = (ambient.scale ?? 1) * (bounce.scale ?? 1);

  const waveOpacity = interpolate(localFrame, [0, 15], [1, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const wavePulse = t * 2;

  // Speech bubble caption
  const captionOpacity = interpolate(localFrame, [5, 25], [0, 1], {
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

      {/* Waveform */}
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

      {/* Speech bubble */}
      <div
        style={{
          position: "absolute",
          top: barHeight + 60,
          left: "50%",
          transform: `translateX(-20%)`,
          zIndex: 25,
          opacity: captionOpacity,
        }}
      >
        <div
          style={{
            backgroundColor: "rgba(255,119,0,0.15)",
            border: "1.5px solid rgba(255,119,0,0.5)",
            borderRadius: 16,
            padding: "12px 20px",
            maxWidth: 320,
            backdropFilter: "blur(8px)",
          }}
        >
          <p
            style={{
              fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
              fontSize: 22,
              fontWeight: 500,
              color: "#ffffff",
              margin: 0,
              fontStyle: "italic",
            }}
          >
            "Whisky is done, Ahmad."
          </p>
        </div>
        {/* Bubble tail */}
        <div
          style={{
            position: "absolute",
            top: -8,
            left: 20,
            width: 0,
            height: 0,
            borderLeft: "8px solid transparent",
            borderRight: "8px solid transparent",
            borderBottom: "8px solid rgba(255,119,0,0.5)",
          }}
        />
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

      {/* Bottom caption */}
      <div
        style={{
          position: "absolute",
          bottom: 100,
          left: 0,
          right: 0,
          padding: "0 50px",
          textAlign: "center",
          opacity: captionOpacity,
        }}
      >
        <p
          style={{
            fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
            fontSize: 38,
            fontWeight: 600,
            color: "#ffffff",
            margin: 0,
            textShadow: "0 2px 16px rgba(0,0,0,0.9)",
          }}
        >
          And{" "}
          <span style={{ color: "#FF7700" }}>says it out loud.</span>
        </p>
      </div>
    </div>
  );
};
