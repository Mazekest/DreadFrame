DREADFRAME v2  -  Minecraft horror shader (Iris / GLSL 120)
==========================================================
Target: MC 1.21.x+ / Iris 1.11.1 / Sodium 0.9.0 / Modrinth App

INSTALL
  Drop this .zip (do NOT unzip) into  .minecraft/shaderpacks/
  In game: Options > Video Settings > Shader Packs > DreadFrame_v1
  Reselecting the pack in that menu = full reload.

WHAT'S NEW IN v2
  A dry-brush / screen-print ink stage sits between the tone ramp and the final
  color. The red/black border is no longer a clean gradient - it gets chewed by
  ridged bristle noise, torn by sparse skip lines, and spattered at the rim.
  New screen: [Dry Brush / Ink]. New profile: WOODCUT.

  The one rule the whole stage is built on: every erosion term MULTIPLIES t.
  t == 0 stays 0, so the ink can never fog up the pure blacks, and solid red
  masses are protected by a core mask so only their rims fray.

FIRST 60 SECONDS
  1. Open Shader Options -> pick profile "PLAYABLE".
  2. Open [Debug] -> DEBUG_VIEW = 3 (linear depth) and 4 (edge mask).
     Confirm depth reads sane and outlines land on block edges. Then set back to 0.
  3. Can't see? Raise VISIBILITY, then AMBIENT_FLOOR, then DARK_RANGE. In that order.
  4. Want the reference-image look for a screenshot? Profile "SCREENSHOT".
  5. Roughness dialing order: DRYBRUSH (how much) -> BRUSH_SCALE (how fine) ->
     BRUSH_STREAK (blotches vs strokes) -> BRISTLE_SKIP / SPECKLE (the extras).

WORLD_LOCK IS THE ONE TO WATCH
  0 = ink printed on your monitor. Walk around and the texture stays put, which
      reads as a silkscreen poster but also as "shader overlay".
  1 = paint stuck to the blocks. Slides correctly as you move. Costs a world
      position reconstruction and a second noise evaluation.
  Judge this one WHILE WALKING. Standing still it looks identical.

PERFORMANCE
  BRUSH_OCTAVES is the knob. 3 = default, 2 if you lose frames, 4 for stills.
  WORLD_LOCK strictly between 0 and 1 evaluates the noise twice - snap it to
  0.00 or 1.00 if you are tight on frames.

TUNING METHOD (one variable at a time)
  Compare two extremes, never a middle value. DREAD 0.0 vs 1.0. OUTLINE 0.0 vs 1.0.
  Anything time-based (PULSE, JITTER, GRAIN) must be judged while moving, not paused.

OPTIONS ARE REMEMBERED BY ZIP FILENAME
  Iris keys saved option values to the pack filename. If you edit the shaders and
  want clean defaults back, rename the zip (v1 -> v2). Otherwise your old slider
  values silently override the new #define defaults.

PIPELINE
  gbuffers_basic / _textured / _textured_lit / _skybasic / _skytextured
    -> colortex0 (albedo)  colortex1 (.r blocklight .g skylight .b material flag)
  composite  : deferred lighting, depth-sobel outlines, darkness falloff,
               dry-brush ink erosion, red grading
  final      : chromatic aberration, torn vignette + heartbeat, chunky ink
               grain with dry pinholes, scanlines

TRAPS HANDLED
  - No gbuffers_terrain/entities/hand/water: they fall back down the chain to
    gbuffers_textured_lit, which is present. Nothing renders black-on-missing.
  - Sun/moon are additive in vanilla -> forced to normal blending in
    shaders.properties and given a luminance-derived alpha, so they stay visible
    without nuking the buffer.
  - No buffer initial values assumed: every gbuffer writes all channels each frame.
  - No const colortexNFormat directives (default RGBA8) - one less thing to typo.
  - Every blend.* line has 4 args or the single token "off". Never 2.
  - depthtex1 is not used at all, so the translucent-player gap never applies.

KNOWN LIMITS
  - Translucents (water, glass) get their lightmap alpha-blended into colortex1.
    Slightly wrong lighting through glass. Stylistically invisible here.
  - Clouds inherit the geometry path and read very dark. Intentional. Set
    clouds = off in shaders.properties if you dislike it.
  - No shadow map, no normals buffer. That's the trade for a pack this small.

DEBUG_VIEW 6
  Shows the brush noise itself: red = bristle ridges, green = fine grit.
  If this looks like soft clouds instead of streaks, BRUSH_STREAK is too low.
