import React from "react";
import { useCurrentFrame, useVideoConfig, interpolate } from "remotion";
import { Mascot, ambientPose } from "../Mascot";
import { MenuBar } from "./SceneDancing";

type FeatureCardProps = {
  icon: string;
  text: string;
  subtext: string;
  opacity: number;
  translateY: number;
};

const FeatureCard: React.FC<FeatureCardProps> = ({
  icon,
  text,
  subtext,
  opacity,
  translateY,
}) => (
  <div
    style={{
      opacity,
      transform: `translateY(${translateY}px)`,
      backgroundColor: "rgba(255,255,255,0.04)",
      border: "1px solid rgba(255,119,0,0.3)",
      borderRadius: 20,
      padding: "24px 32px",
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 10,
      width: "100%",
      maxWidth: 460,
    }}
  >
    <span style={{ fontSize: 52 }}>{icon}</span>
    <p
      style={{
        fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
        fontSize: 34,
        fontWeight: 700,
        color: "#FF7700",
        margin: 0,
        textAlign: "center",
      }}
    >
      {text}
    </p>
    <p
      style={{
        fontFamily: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
        fontSize: 26,
        fontWeight: 400,
        color: "rgba(255,255,255,0.7)",
        margin: 0,
        textAlign: "center",
      }}
    >
      {subtext}
    </p>
  </div>
);

const features = [
  {
    icon: "👋",
    text: "Slap your Mac",
    subtext: "→ Opens Claude instantly",
  },
  {
    icon: "🎤",
    text: `Say "hey Claude"`,
    subtext: "→ Voice trigger, opens Claude",
  },
  {
    icon: "☕",
    text: "Keeps Mac awake",
    subtext: "While Claude is working",
  },
];

export const SceneFeatures: React.FC<{ startFrame: number }> = ({ startFrame }) => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();

  const localFrame = frame - startFrame;
  const t = localFrame / fps;
  const barHeight = 44;
  const mascotSize = 50;

  // 7 seconds = 210 frames. Each card gets ~2.3s = 70 frames.
  const cardDuration = 70;
  const cardIndex = Math.min(2, Math.floor(localFrame / cardDuration));

  // Current card opacity/position
  const cardProgress = (localFrame % cardDuration) / cardDuration;

  // Ambient dance
  const ambient = ambientPose(t, 185);

  // Mascot gesture per card
  // Card 0 (slap): hop
  // Card 1 (voice): rotate
  // Card 2 (awake): idle + coffee icon
  const hopY = cardIndex === 0 && cardProgress < 0.3
    ? Math.sin((cardProgress / 0.3) * Math.PI) * -20
    : 0;

  const extraRotation = cardIndex === 1
    ? Math.sin(t * Math.PI * 2 * 2) * 15
    : 0;

  const currentMascotX = ambient.x ?? 0;

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

      {/* Mascot */}
      <div
        style={{
          position: "absolute",
          top: barHeight - 4,
          left: "50%",
          transform: `translateX(calc(-50% + ${currentMascotX}px))`,
          zIndex: 20,
        }}
      >
        <Mascot
          pose={{
            y: hopY + (ambient.y ?? 0),
            rotation: (ambient.rotation ?? 0) + extraRotation,
            scale: ambient.scale ?? 1,
          }}
          size={mascotSize}
        />
        {/* Coffee icon for card 2 */}
        {cardIndex === 2 && (
          <div
            style={{
              position: "absolute",
              top: -20,
              right: -24,
              fontSize: 28,
              opacity: interpolate(localFrame, [cardDuration * 2, cardDuration * 2 + 20], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              }),
            }}
          >
            ☕
          </div>
        )}
      </div>

      {/* Feature cards — centered below menu bar */}
      <div
        style={{
          position: "absolute",
          top: "50%",
          left: 0,
          right: 0,
          transform: "translateY(-50%)",
          display: "flex",
          justifyContent: "center",
          padding: "0 40px",
        }}
      >
        {features.map((f, i) => {
          const isActive = i === cardIndex;
          const cardLocalProgress = Math.max(0, (localFrame - i * cardDuration));
          const opacity = isActive
            ? interpolate(cardLocalProgress, [0, 15], [0, 1], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              })
            : 0;
          const ty = isActive
            ? interpolate(cardLocalProgress, [0, 15], [30, 0], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              })
            : 0;

          return (
            <FeatureCard
              key={i}
              icon={f.icon}
              text={f.text}
              subtext={f.subtext}
              opacity={opacity}
              translateY={ty}
            />
          );
        })}
      </div>
    </div>
  );
};
