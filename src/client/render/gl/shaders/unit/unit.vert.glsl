#version 300 es
precision highp float;

layout(location = 0) in vec2 aPos;

// Per-instance attributes
layout(location = 1) in vec3 aInstPos;   // x, y, ownerID
layout(location = 2) in vec4 aInstFlags; // atlasIdx, flags, flickerHash, heading (uint8→float)

uniform mat3  uCamera;

uniform float uUnitSize;
uniform float uHBombGlowScale; // quad enlargement for the hydrogen bomb glow halo
uniform float uTick;

out vec2  vQuadPos;     // quad coords [0,1] — drives the radial glow falloff
out vec2  vCellUV;      // sprite cell coords; the central 1/scale region is the sprite
out vec2  vWorldPos;    // world-space tile coords — drives the train effect's gradient
flat out float vAtlasCol;
flat out float vOwnerID;
flat out float vFlags;  // 0.0 = normal, 1.0 = flicker, 2.0 = angry
flat out float vHash;   // per-instance hash for flicker phase offset
flat out float vGlow;   // 1.0 if this instance is a hydrogen bomb (draw glow), else 0.0
flat out float vIsHalloween;

void main() {
  float worldX = aInstPos.x;
  float worldY = aInstPos.y;
  vOwnerID = aInstPos.z;

  float atlasCol = aInstFlags.x;
  vFlags = aInstFlags.y;
  vAtlasCol = atlasCol;

  // Per-instance hash so each unit flickers independently. Computed CPU-side
  // from the tick position — hashing worldX/Y here would re-roll the phase
  // every frame for nukes whose position is smoothed per frame.
  vHash = aInstFlags.z * (1.0 / 255.0);

  // Hydrogen bombs render an enlarged quad so there's room for a glow halo
  // around the sprite. All other units keep scale 1 (no behavior change).
  float isHBomb = step(abs(atlasCol - float(HYDROGEN_BOMB_COL)), 0.5);
  vGlow = isHBomb;
  float scale = mix(1.0, uHBombGlowScale, isHBomb);

  // Check if unit is a custom Halloween nuke (Atom, HBomb, MIRV, MIRV Warhead)
  float isHalloween = (
    abs(atlasCol - float(ATOM_BOMB_COL)) < 0.5 ||
    abs(atlasCol - float(HYDROGEN_BOMB_COL)) < 0.5 ||
    abs(atlasCol - float(MIRV_COL)) < 0.5 ||
    abs(atlasCol - float(MIRV_WARHEAD_COL)) < 0.5
  ) ? 1.0 : 0.0;
  vIsHalloween = isHalloween;

  // Scale up the custom Halloween icons by 1.6x so they have more screen space, but aren't massive
  float spriteScale = mix(1.0, 1.6, isHalloween);

  // UNIT_SIZE is in world-space tiles — no zoom division needed.
  // Units scale with the map like territory tiles do.
  float halfSize = uUnitSize * 0.5 * scale * spriteScale;

  vec2 quadOffset = aPos - 0.5;
  bool flipGhostX = false;

  // Dynamic ghost direction for Hydrogen Bomb
  if (isHBomb > 0.5) {
    float headingVal = aInstFlags.w; // 1..255 (0 = unassigned)
    if (headingVal > 0.5) {
      float angle = (headingVal - 1.0) * 0.02473695; // (2 * PI) / 254.0
      float dirX = cos(angle);
      float dirY = sin(angle);
      flipGhostX = (dirX < -0.05);

      // Pitch tilt towards flight direction if moving vertically
      if (abs(dirY) > 0.02) {
        float tilt = clamp(dirY * (flipGhostX ? -0.35 : 0.35), -0.4, 0.4);
        float cosT = cos(tilt);
        float sinT = sin(tilt);
        quadOffset = vec2(
          quadOffset.x * cosT - quadOffset.y * sinT,
          quadOffset.x * sinT + quadOffset.y * cosT
        );
      }
    }
  }

  vec2 center = vec2(worldX + 0.5, worldY + 0.5);
  vec2 worldPos = center + quadOffset * halfSize * 2.0;
  vWorldPos = worldPos;

  vec3 clip = uCamera * vec3(worldPos, 1.0);
  gl_Position = vec4(clip.xy, 0.0, 1.0);

  vQuadPos = aPos;

  // Map the enlarged quad back to sprite cell space: the central 1/scale
  // portion is the sprite, anything outside [0,1] is glow-only margin.
  vCellUV = (aPos - 0.5) * scale + 0.5;

  if (flipGhostX) {
    vCellUV.x = 1.0 - vCellUV.x;
  }
}
