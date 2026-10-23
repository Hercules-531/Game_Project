# M40 — Underground trace and forced entrances

M40a covers real-work noise and the airlock. M40b completes rail mouths and thin
lining with physical ingress paths; it is not replaced by an abstract damage roll.

Engineering choices under the continuing authorization:

- A paid drilling motor emits a 180m vibration pulse every five supplied work
  seconds, positioned at its current tunnel front (or room). Actual rail travel
  emits every ten metres per segment at reach 80 + 0.2×payload kg. The passenger
  counts as 80kg. These use the same emissions/trace system as surface sound,
  including muffling through cover. Idle, unfunded or blocked work creates no
  free movement noise. Partial distance/work clocks persist without reload spam.
- Each entrance owns condition 0–100, plating tier 0–3, contact clock and forced
  state. Airlock outer and inner seals are separate barriers. A living, unstunned
  existing mutant must be physically within 1.8m and clear reach; no actor is
  spawned or moved inside by a probability result.
- At local trace ≥40, each ten seconds of hostile contact samples the seeded
  forcing risk: (0.03 + 0.12×clamp((trace-40)/60,0,1)) × (2-condition/100),
  divided by 1+2×plating tier. Existing intact static defenses multiply by 0.8,
  or 0.6 when energized. A 0.001 floor remains while eligible. Low trace/no
  contact makes no attempt. Claw strikes wear condition by damage/10/(tier+1).
- Successful forcing disables the actual seal collider and opens its damaged
  mesh. The inner door still blocks after outer failure. Existing light/stun,
  perimeter damage and siege retreat remain meaningful. An intruder then uses
  ordinary senses and physical interior patrol paths; it can kill the unprotected
  operator. Last-good-save death handling remains unchanged.
- Defense research permits one plating tier for 24 local scrap. A damaged seal
  costs ceil((100-condition)×0.2), plus eight scrap if forced. A powered torch
  hull at the source workshop/cradle/FOB spends 0.02kWh per service action;
  heavy hulls use their actual tender/pylon with the existing 90% transfer rule.
  Torch efficiency scales the 15s tool cooldown. Like existing workshop/perimeter
  service, this is an immediate paid action, not an unseen builder or free hull.
  Sealing rejects an occupied aperture. Plating never guarantees immunity.
- Save v34 preserves entrance damage/plating/forcing, contact and noise clocks,
  cooldowns, RNG and existing-actor ingress stages. Older saves get intact seals
  without free plating. Forced doors are distinct from voluntary airlock cycling;
  a damaged opposite seal prevents normal opening but never prevents safe closing.

M40a files: entrance_state.gd, breach_system.gd, action_power.gd, airlock and
mutant control/senses, emissions/trace, excavation/rail work hooks, hardening UI,
save schema and breach tests. Existing PSX metal supplies native plating; no
new bitmap/sound source is introduced. M41 will make these emissions audible.

Verify no idle noise, paid work/distance attribution, persistent pulse cadence,
risk bounds and nonzero fortified risk, real contact/cover, actual two-seal
crossing, barrier/light/stun counters, finite local service costs, occupancy,
bare-operator danger and last-good save protection, route/RNG reload and the
640×480 terminal. M40b must separately exercise every additional entrance type.

M40b physical layout: each finished held-hub segment receives two fixed service
connections, included in its commissioned lining: a bulkheaded rail mouth near
the forward hub and an unsealed chase ending at a 60-condition lining panel
near the segment midpoint. Each uses a two-metre-wide switchback: two 9m runs
and a 2×5m landing descend from surface Y0 to the tunnel floor Y=-6. Geometry
clips only the required surface slab and tunnel cells; double-sided solid roofs
and sides prevent bypassing a gate by falling through an outside face. The
mouth seal is at the top; the lining seal is at the bottom. Anchors persist when
other rooms/tunnels widen. Existing cleared chase volume is excluded from later
excavation quotes. No connection crosses unheld/unknown ground.

Actors follow the actual landing/ramp route, then the earned tunnel chain. At
home the existing service ladder is a continuous kinematic climb, with swept
collision and an independently forceable hatch; no vertical teleport substitutes
for reaching the bunker. Stun/light can interrupt climbing. Local trace and
local defenses govern each seal; source-hub stock and a nearby powered torch
hull pay for field service. Indoor classification follows real owned volumes,
including ramp elevation, rather than treating all northern ground as outdoors.
Portal lamps use 0.02kW per healthy source port with fresh payment. Precipitation
is clipped by native roof volumes. Save v35 preserves layout and route/climb
progress and migrates v34 airlock state without granting plating.
Already-paid pre-chase excavation jobs retain their exact original quoted
scrap/time through migration; new requests deduct the cleared chase volume.
