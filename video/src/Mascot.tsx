import React from "react";
import { Img, staticFile, useCurrentFrame, useVideoConfig, interpolate, spring } from "remotion";

export type MascotPose = {
  x?: number;
  y?: number;
  rotation?: number;
  scale?: number;
  opacity?: number;
};

// Replicates the Swift choreography math
export function ambientPose(t: number, seatHalfWidth: number): MascotPose {
  const danceDuration = 60.0;
  const walkDuration = 8.0;
  const cycleDuration = (danceDuration + walkDuration) * 2.0;

  const cycle = t % cycleDuration;
  const seat = seatHalfWidth;

  const s1 = danceDuration;
  const s2 = s1 + walkDuration;
  const s3 = s2 + danceDuration;

  // Universal breathing scale
  const breathScale = 1.0 + (1.0 + Math.sin(t * 2 * Math.PI / 3.5)) * 0.009;

  if (cycle < s1) {
    // DANCE LEFT
    const sway = Math.sin(t * 2 * Math.PI * 0.55) * 2.5;
    const nod = Math.sin(t * 2 * Math.PI * 0.45) * 4.5;
    const beatScale = 1.0 + Math.max(0, Math.sin(t * 2 * Math.PI * 0.5)) * 0.025;
    return { x: -seat + sway, y: 0, scale: breathScale * beatScale, rotation: nod };
  } else if (cycle < s2) {
    // WALK LEFT -> RIGHT
    const f = (cycle - s1) / walkDuration;
    const easedF = smoothstep(f);
    const baseX = -seat + 2 * seat * easedF;

    const stepPhase = (t * 1.6) % 1.0;
    const footstep = stepPhase < 0.35 ? Math.sin((stepPhase / 0.35) * Math.PI) * 2.0 : 0;
    const lean = 5.0;
    const middleDist = Math.abs(baseX) / seat;
    const duckScale = 1.0 - (1.0 - middleDist) * 0.08;
    const duckY = (1.0 - middleDist) * 1.5;
    return { x: baseX, y: footstep + duckY, scale: breathScale * duckScale, rotation: lean };
  } else if (cycle < s3) {
    // DANCE RIGHT
    const sway = Math.sin(t * 2 * Math.PI * 0.55) * 2.5;
    const nod = Math.sin(t * 2 * Math.PI * 0.45) * 4.5;
    const beatScale = 1.0 + Math.max(0, Math.sin(t * 2 * Math.PI * 0.5)) * 0.025;
    return { x: seat + sway, y: 0, scale: breathScale * beatScale, rotation: nod };
  } else {
    // WALK RIGHT -> LEFT
    const f = (cycle - s3) / walkDuration;
    const easedF = smoothstep(f);
    const baseX = seat - 2 * seat * easedF;

    const stepPhase = (t * 1.6) % 1.0;
    const footstep = stepPhase < 0.35 ? Math.sin((stepPhase / 0.35) * Math.PI) * 2.0 : 0;
    const lean = -5.0;
    const middleDist = Math.abs(baseX) / seat;
    const duckScale = 1.0 - (1.0 - middleDist) * 0.08;
    const duckY = (1.0 - middleDist) * 1.5;
    return { x: baseX, y: footstep + duckY, scale: breathScale * duckScale, rotation: lean };
  }
}

function smoothstep(x: number): number {
  const c = Math.max(0, Math.min(1, x));
  return c * c * (3 - 2 * c);
}

// Attention bounce (3 jumps, 360° spin, scale to 1.45)
export function attentionPose(bounceProgress: number): MascotPose {
  // bounceProgress: 0..1 over ~1 second
  const bounces = 3;
  const perBounce = 1.0 / bounces;

  let offset = 0;
  let rotation = 0;
  let scale = 1.0;

  for (let i = 0; i < bounces; i++) {
    const start = i * perBounce;
    const end = (i + 1) * perBounce;
    const down = perBounce * 0.45;

    if (bounceProgress >= start && bounceProgress < end) {
      const local = (bounceProgress - start) / perBounce;
      if (local < 0.45) {
        // Going up
        const t = local / 0.45;
        const arc = Math.sin(t * Math.PI);
        offset = arc * 22;
        scale = 1.0 + arc * 0.45;
        rotation = (360 / bounces) * (i + t);
      } else {
        // Coming down
        const t = (local - 0.45) / 0.55;
        offset = Math.sin((1 - t) * Math.PI * 0.5) * 22 * (1 - t);
        scale = 1.0 + (1 - t) * 0.45 * 0.3;
        rotation = (360 / bounces) * (i + 1);
      }
    }
  }

  if (bounceProgress >= 1.0) {
    rotation = 0;
    offset = 0;
    scale = 1.0;
  }

  return { y: -offset, rotation, scale };
}

// Done bounce (2 jumps, 180° spin, scale to 1.25)
export function donePose(bounceProgress: number): MascotPose {
  const bounces = 2;
  const perBounce = 1.0 / bounces;

  let offset = 0;
  let rotation = 0;
  let scale = 1.0;

  for (let i = 0; i < bounces; i++) {
    const start = i * perBounce;
    const end = (i + 1) * perBounce;

    if (bounceProgress >= start && bounceProgress < end) {
      const local = (bounceProgress - start) / perBounce;
      if (local < 0.45) {
        const t = local / 0.45;
        const arc = Math.sin(t * Math.PI);
        offset = arc * 14;
        scale = 1.0 + arc * 0.25;
        rotation = (180 / bounces) * (i + t);
      } else {
        const t = (local - 0.45) / 0.55;
        offset = Math.sin((1 - t) * Math.PI * 0.5) * 14 * (1 - t);
        scale = 1.0 + (1 - t) * 0.25 * 0.3;
        rotation = (180 / bounces) * (i + 1);
      }
    }
  }

  if (bounceProgress >= 1.0) {
    rotation = 0;
    offset = 0;
    scale = 1.0;
  }

  return { y: -offset, rotation, scale };
}

type MascotProps = {
  pose: MascotPose;
  size?: number;
  opacity?: number;
};

export const Mascot: React.FC<MascotProps> = ({ pose, size = 64, opacity = 1 }) => {
  const { x = 0, y = 0, rotation = 0, scale = 1 } = pose;

  return (
    <div
      style={{
        transform: `translate(${x}px, ${y}px) rotate(${rotation}deg) scale(${scale})`,
        transformOrigin: "center center",
        opacity,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        filter: "drop-shadow(0px 4px 8px rgba(0,0,0,0.5))",
        willChange: "transform",
      }}
    >
      <Img
        src={staticFile("claude-logo.svg")}
        style={{ width: size, height: size, display: "block" }}
      />
    </div>
  );
};
