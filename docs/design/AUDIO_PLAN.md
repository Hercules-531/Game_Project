# M41 — Synthesized operational audio

Continuing authorization permits native synthesis. No external recordings,
pack demo music or new texture assets are used. This checkpoint changes
presentation, not sensing thresholds, power costs or threat behavior.

- Generate short deterministic 16-bit mono PCM streams in memory: low machine
  motor, metallic drill/rail/impact, soft boot/claw steps, sonar chirp/echo,
  breath, two alarm cadences and weather noise. Keep headroom and fade clip
  edges; no music. Cache streams across world reloads.
- A root-viewport 3D listener follows the operator's camera. While the fleet
  terminal is open with a powered, deployed, linked selection, it follows that
  hull's sensor-eye transform and attenuates the received world mix by link
  quality. A severed feed returns to bunker hearing, without distant threat
  revelation. Root spatial voices use real source positions, distance and
  concrete occlusion; native stereo panning follows listener rotation.
- Machine loops use the exact sound reach already consumed by mutant senses.
  Silent running lowers them; an installed thermal siphon silences the small
  hull exactly when emissions say it does. Drill, rail, decoy, trap and claw
  impacts subscribe to existing physical emission events. Radio/heat/light
  are not audible. Organic footsteps occur only on actual living movement.
- Sonar chirps only after a successful real ping. Delayed return tones use
  fresh measured geometry/contact distances, reach and the active link;
  blocked, unpowered, silent or cooling-down pings create no sound.
- Bunker ventilation follows actual paid supply; weather follows the current
  condition and is muffled indoors. Suit breath and low oxygen/filter cadence
  require an active living suit. Existing life-support warnings sound at the
  operator/console, with a faster critical cadence; these local instruments
  do not broadcast new world emissions to mutants.
- World sounds use Effects, ventilation/weather use Ambience, all through
  Master. Existing settings mute each bus; pause pauses playback and timers.
  Reload reconstructs current loops without replaying old transient events.
  A Master limiter caps overlapping effects at -1dB.

Files: native audio synth/director and rig, main scene instance, audio buses,
an audible presentation signal beside the unchanged AI emission signal, explicit
sonar cue attribution, gameplay audio tests and evidence. Verify waveform headroom/determinism, real 3D direction,
distance/cover attenuation, silent/power/link gating, fresh sonar cadence,
warning urgency, weather/suit/volume buses, pause/reload and an actual rendered
runtime. Audibility and subjective mix quality require human listening too;
automated mixing checks cannot establish the desired horror atmosphere.
