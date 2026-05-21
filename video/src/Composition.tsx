import React from "react";
import { AbsoluteFill, useCurrentFrame, useVideoConfig, interpolate } from "remotion";
import { SceneHook } from "./scenes/SceneHook";
import { SceneMascotReveal } from "./scenes/SceneMascotReveal";
import { SceneDancing } from "./scenes/SceneDancing";
import { SceneAttention } from "./scenes/SceneAttention";
import { SceneSound } from "./scenes/SceneSound";
import { SceneFeatures } from "./scenes/SceneFeatures";
import { SceneStory } from "./scenes/SceneStory";
import { SceneCTA } from "./scenes/SceneCTA";

// Scene timing @ 30fps (45s total = 1350 frames)
// 0-3s    = 0-90      Hook card
// 3-8s    = 90-240    Mascot reveal (5s)
// 8-15s   = 240-450   Dancing + walk (7s)
// 15-20s  = 450-600   Attention event (5s)
// 20-25s  = 600-750   Sound moment (5s)
// 25-32s  = 750-960   Features quick-cut (7s)
// 32-39s  = 960-1170  The story (7s)
// 39-45s  = 1170-1350 CTA (6s)

export const SCENES = [
  { name: "hook", start: 0, end: 90 },
  { name: "reveal", start: 90, end: 240 },
  { name: "dancing", start: 240, end: 450 },
  { name: "attention", start: 450, end: 600 },
  { name: "sound", start: 600, end: 750 },
  { name: "features", start: 750, end: 960 },
  { name: "story", start: 960, end: 1170 },
  { name: "cta", start: 1170, end: 1350 },
];

const TRANSITION_FRAMES = 8; // crossfade duration

type SceneWrapperProps = {
  children: React.ReactNode;
  sceneStart: number;
  sceneEnd: number;
};

const SceneWrapper: React.FC<SceneWrapperProps> = ({ children, sceneStart, sceneEnd }) => {
  const frame = useCurrentFrame();

  // Fade in at start
  const fadeIn = interpolate(frame, [sceneStart, sceneStart + TRANSITION_FRAMES], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Fade out at end
  const fadeOut = interpolate(
    frame,
    [sceneEnd - TRANSITION_FRAMES, sceneEnd],
    [1, 0],
    {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }
  );

  const opacity = Math.min(fadeIn, fadeOut);
  const isVisible = frame >= sceneStart - TRANSITION_FRAMES && frame <= sceneEnd + TRANSITION_FRAMES;

  if (!isVisible) return null;

  return (
    <AbsoluteFill style={{ opacity }}>
      {children}
    </AbsoluteFill>
  );
};

export const WhiskyClaudeComposition: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{ backgroundColor: "#000000" }}>
      <SceneWrapper sceneStart={0} sceneEnd={90}>
        <SceneHook />
      </SceneWrapper>

      <SceneWrapper sceneStart={90} sceneEnd={240}>
        <SceneMascotReveal startFrame={90} />
      </SceneWrapper>

      <SceneWrapper sceneStart={240} sceneEnd={450}>
        <SceneDancing startFrame={240} />
      </SceneWrapper>

      <SceneWrapper sceneStart={450} sceneEnd={600}>
        <SceneAttention startFrame={450} />
      </SceneWrapper>

      <SceneWrapper sceneStart={600} sceneEnd={750}>
        <SceneSound startFrame={600} />
      </SceneWrapper>

      <SceneWrapper sceneStart={750} sceneEnd={960}>
        <SceneFeatures startFrame={750} />
      </SceneWrapper>

      <SceneWrapper sceneStart={960} sceneEnd={1170}>
        <SceneStory startFrame={960} />
      </SceneWrapper>

      <SceneWrapper sceneStart={1170} sceneEnd={1350}>
        <SceneCTA startFrame={1170} />
      </SceneWrapper>
    </AbsoluteFill>
  );
};
