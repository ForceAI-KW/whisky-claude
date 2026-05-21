import React from "react";
import { Composition } from "remotion";
import { WhiskyClaudeComposition } from "./Composition";

// 45 seconds @ 30fps = 1350 frames
const DURATION = 1350;
const FPS = 30;

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* Vertical 1080×1350 — LinkedIn default feed format */}
      <Composition
        id="WhiskyClaudeLaunch"
        component={WhiskyClaudeComposition}
        durationInFrames={DURATION}
        fps={FPS}
        width={1080}
        height={1350}
        defaultProps={{}}
      />

      {/* Square 1080×1080 — LinkedIn fallback */}
      <Composition
        id="WhiskyClaudeLaunchSquare"
        component={WhiskyClaudeComposition}
        durationInFrames={DURATION}
        fps={FPS}
        width={1080}
        height={1080}
        defaultProps={{}}
      />
    </>
  );
};
