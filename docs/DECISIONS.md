# Implementation decisions

22 September 2026 — User-requested visual correction, before M12:
the user reported textures moving with the player and an excessively old-looking
image. Disable camera-dependent affine UV distortion and vertex snapping by
default; retain them only as diagnostic switches. Increase the framebuffer from
320×240 to 640×480 (four times the pixel count), with a 1280×960 default window.
Scale interface typography/layout to retain its physical screen proportions.
Reduce compositor dither strength to 0.35, chroma to 0.05, grain to 0.004.
PSX asset priority, surface-local UVs, 64px source imports and nearest sampling
remain. This explicit user request supersedes the earlier PS1 distortion rule.

The user subsequently directed autonomous completion of all milestones and a
polished playable result. Routine review gates in the initial plan are now
resolved by documented implementation decisions and rendered verification,
without repeatedly stopping for approval. Explicit GDD mechanics remain binding.
Meaningful contradictions that cannot be resolved from the document still require
clarification; feature omissions are not an acceptable shortcut.

The confirmed direction remains PS1 rendering, PSX house assets first, custom
low-poly meshes for gaps, and a compact bunker with command, workshop, life
support and airlock functions. Visual reviews will be saved with the milestones.

M03: operator walk speed starts at 2.6 m/s, with 16 m/s² acceleration and
20 m/s² deceleration, a 0.3 m radius / 1.7 m capsule, and physical WASD keys.
These are exposed tuning values, not claimed GDD constants. No jump or sprint
mechanic is added. Physics tests check speed and collision across tick rates.

M04: eye height 1.55m, FOV 75°, pitch clamp ±80°, sensitivity 0.0025 rad/pixel.
Escape currently releases/recaptures the pointer; M11 will connect it to the
pause menu. Terminal and menu contexts block walking and look immediately.

M13a: settings use physical keyboard positions for movement/use. Assigning an
occupied key swaps the two actions so no action becomes inaccessible. Escape
is reserved for back/pause and cancels an active rebind before closing settings.
Preferences persist independently of campaign saves and apply immediately.
Master, Effects and Ambience buses start at unity gain; mouse sensitivity ranges
from 0.0005 to 0.006 radians/pixel with the existing 0.0025 default.
