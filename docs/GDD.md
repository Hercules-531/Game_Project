## PROJECT OUTPOST

DESIGN DOCUMENT

REV. 0.5 — 12 SEP 2026

STATUS: PRE-PRODUCTION

[01](#page-0)

[04](#page-0)

[07](#page-0)

[10](#page-0)

TARGET RUN:

≈40 HOURS TO RESTORATION

O P E R A T I O N S M A N U A L · B U N K E R 1 4 · C L A S S I F I E D

[Core fantasy](#page-0)

[02](#page-0)

[Architecture & loop](#page-0)

[03](#page-0)

[Mechanoid engineering](#page-0)

[Telemetry & autonomy](#page-0)

[05](#page-0)

[The surface](#page-0)

[06](#page-0)

[Threat ecosystem](#page-0)

[Artifacts](#page-0)

[08](#page-0)

[Human sortie](#page-0)

[09](#page-0)

[Excavation & defense](#page-0)

[NEW](#page-0)

[World scale & pacing](#page-0)

[11](#page-0)

[Open questions](#page-0)

## PROJECT OUTPOST DESIGN DOCUMENT

You never go outside. You send machines, you watch them on bad cameras, and you get them home before the batteries die.

```
GENRE SURVIVAL / REMOTE OPS SIM REFERENCE DUSKERS × VOICES OF THE VOID
VIEW 1ST-PERSON BUNKER + DRONE FEEDS
```

## SEC 01 HIGH CONCEPT & CORE FANTASY

A slow-burn survival simulation that splits into two worlds: the tactile, analog interior of a sealed bunker, and the frozen, irradiated surface you only ever see through a drone's sensor feed.

You are an isolated operator sealed underground after the collapse. The surface is toxic, sub-zero, and prowled by sound-sensitive mutants. To


survive — and eventually to reclaim it — you assemble, program and dispatch remote mechanoids to scavenge, build outposts and decontaminate the wasteland.

Every mechanic bends toward one pressure: going outside yourself must feel like failure. Losing a drone in the field is expensive; walking out in a hazard suit to retrieve it is a horror sequence. The clever use of machines to save other machines is the game.

THE ULTIMATE RISK

If the fleet is wiped out or stranded past signal range, survival forces you into an analog hazard suit with a portable jumper battery, on foot, in the dark. See Sec 08. [URL 🔗](#page-0)

## SEC 02 ARCHITECTURE & CORE LOOP

Three layers stack, and the game's long arc is the player's attention migrating downward through them — from desperate scavenging, to territorial expansion, to digging in and hardening what's already been claimed.

```
│ LAYER 1: THE BUNKER INTERIOR │
│ • 1st-person tactile terminals, CRTs, physical toggle switches │
│ • Life support systems (O2, heating, power generation, rations) │
│ • Workshop / fabrication bay (chassis assembly, part repairs) │
│ command telemetry & radio links
│ LAYER 2: THE SURFACE EXPEDITION │
│ • Remote piloting via sensor feeds (sonar, IR, low-res CCD) │
│ • Environmental navigation (blizzards, acid rain, solar windows) │
│ • POI salvage, towing derelicts, and mutant evasion │
│ resource extraction & territory
│ LAYER 3: EXCAVATION & THE HARDENED BASE │
│ • Logistic sorties dig tunnels & rooms to a commanded footprint │
│ • Rail network moves cargo automatically — and carries the player │
```


│

│

## FIG. 2.1 — LAYER STACK AND COMMAND FLOW

## OPENING LOADOUT — THE FIRST HOUR

The player starts with two machines and no eyes. A salvage drone with no vision sensor at all — only rudimentary IR and sonar, enough to find an object and drag it home — and a logistics drone carrying a grainy monochrome camera, good only for supporting the first one. The first real camera is a discovery, not an unlock.

## SEC 03 MECHANOID ENGINEERING

There is no "builder robot" or "combat robot" in the fabrication list. There are hulls with sockets. A machine's role is whatever the operator bolted onto it this morning, and reconfiguring between sorties is expected — strip the turret off a scout to fit a floodlight and a signal emitter, and it becomes a mapping rig.


## HULL ARCHETYPES

## LIGHT QUADRUPED

## "MULE" CLASS

High payload-to-weight ratio, silent footing,

steps over debris. Fast and cheap to run — but structurally fragile, crushed by a single serious hit.

Draw: low · Noise: minimal

## TRACKED WEDGE

## SCOUT / HAULER

Incline stability and immense towing torque — the derelict-recovery workhorse. Bogs down in deep mud and sludge without tread scrapers.

Draw: moderate · Noise: high

## SIZING AND POWER TETHERING

- Small / medium chassis — self-contained internal cells, sufficient for short-to-medium sorties. This is where most of the game is played.

- Large / builder chassis — draw so brutal that internal cells alone are a non-starter. Requires an accompanying tender drone, a rolling battery bank on a physical umbilical, or a chain of field charging pylons. The tender is a second machine to protect, and that is the point: heavy work turns one sortie into a convoy problem.

- Size buffs scale with draw — each step up in socket size grants stronger modules at a steeper power cost, so bigger is a logistics commitment, never a straight upgrade.

## HEAVY QUADRUPED

## "GOLIATH" CLASS

Industrial hauling and armor mounting; the only thing that moves prefab structures out to a camp site. Extremely slow, seismic footfalls that carry for hundreds of metres.

Draw: severe · Noise: extreme

## BIPED STRIKER

## AGILE PLATFORM

Balanced hardpoints, climbs and manoeuvres where nothing else fits. Mechanically complex, high joint wear, constant maintenance appetite.

Draw: moderate · Wear: high

## PART CONDITION AND REPAIR

Every socketed part carries a condition from 0 to 100%. Joints, treads, bearings and lenses wear with use and with the surface hazards in Sec 05. Scrap brought back through the airlock is what repairs them — so the salvage run is not only for building new machines, it is what keeps the ones you have honest. [URL 🔗](#page-0)


| CONDITION | EFFICIENCY | MALFUNCTION | READS AS |
| --- | --- | --- | --- |
|   |   | CHANCE |   |
| 0 – 20% | Functions, but | 50% | A part you should not have taken out. |
|   | barely |   | Every sortie on it is a coin flip. |
| 20 – 80% | Normal | 10% | Working order. The band most of the |
|   |   |   | fleet lives in between overhauls. |
| ABOVE 80% | +20% | None | Freshly serviced. Faster legs, a cleaner |
|   |   |   | lens, a battery that holds its rating. |

The bands do the design work: the top band is a reward for spending scrap on maintenance rather than hoarding it, and the bottom band is a real hazard, not a nag — a hull with a 50% joint is a hull that may not come home. Weather and abrasive terrain push parts down the scale faster; the sandstorm hazard in Sec 05 is, mechanically, a condition drain.

## SEC 04 TELEMETRY, SENSORS & AUTONOMY

What the player knows is a resource as scarce as fuel. Vision is earned hardware, not a given, and the link that carries it is unreliable by design.

## OPTICAL TIERS

| TIER 0 | Blind. Sonar wireframe blips painted on ping, plus thermal gradients. You infer |
| --- | --- |
|   | what an obstacle is from its geometry and its heat — a warm silhouette in a doorway |
|   | could be a vent or a mutant. |
| TIER 1 | Scavenged CCD. 15 FPS monochrome, heavy scanline static, blooming in light and |
|   | swallowed by darkness. Enough to identify salvage, not enough to trust. |
| TIER 2+ | Multi-spectrum optics. Clean framerate, night-vision overlays, digital zoom and |
|   | automated object classification tags. Endgame clarity, and expensive to keep |
|   | running. |
| SIGNAL PHYSICS |   |


- Distance & occlusion — the link degrades through concrete, subterranean vaults and mineral ridges, so a map's geology dictates where control ends.

- Packet loss & latency — severe weather introduces 1–2 seconds of input lag and video breakup before it cuts out entirely.

- Random fluctuation — even well inside nominal range, the link can drop on its own. This is why you send drones in pairs: a second set of sensors nearby tells you what happened to the first.

- Total blackout — on severance, a bot executes its fail-safe: freeze, or retrace waypoints to last known link. A retrace module is the single most valuable early-game purchase.

- Relay chains — high-gain dish scouts parked on ridges act as repeaters; power pylons extend both charge and network outward, and the expanding relay web is the physical shape of your progress.

## RULE-BLOCK AUTONOMY

No syntax, no programming background required. The player assembles decision trees from physical blocks on a bunker terminal — readable aloud as a sentence, and legible at a glance while three sorties are running.

```
[Target: POI — cargo wreck]
├── [ACTION: Move to waypoint]
├── [CONDITION: If battery < 20%] ──────► [ACTION: Abort & return to base]
├── [CONDITION: If hostile audio ping] ─► [ACTION: Kill lights & go silent]
└── [CONDITION: If scrap found] ────────► [ACTION: Load cargo & attach winch]
FIG. 4.1 — VISUAL ORDER SCRIPT, TERMINAL VIEW
```

## SEC 05 THE SURFACE

Weather is not flavour — it is the scheduling layer. Sorties are planned against a forecast, and every condition that hurts you helps you somewhere else.


| CONDITION | HAZARD | EXPLOIT |
| --- | --- | --- |
| CRISP SUNLIGHT | Long-range visibility exposes | +50–100% solar charge. The window for |
|   | you to anything watching. | deep-field rescues and tender hauls. |
| THICK ION SMOG | Radio range cut 40%, heavy | Mutant sensory range halved — stealth scrap |
|   | optical static. | runs into nests with IR-only scouts. |
| ABRASIVE SAND / ASH | Jams track bearings, scours | Wind strips topsoil and exposes buried pre- |
|   | camera lenses, raises | collapse caches. |
|   | malfunction odds. |   |
| ACID RAIN | Short-circuit risk, accelerated | Decontaminates radioactive hot-spots and |
|   | armor rot. | drives mutant patrols under cover. |
| GEOTHERMAL POCKETS | Volatile venting, unstable | Freeze-drain drops to zero — natural staging |
|   | ground. | and charging havens. |
| SOLAR FLARE / EM AURORA | Wireless control scrambled | Ambient fields overload field capacitors: |
|   | completely. | temporary unlimited local power for scripted |
|   |   | off-grid runs. |

## STANDING HAZARDS

- Part degradation — components wear with distance and load; a neglected joint fails mid-sortie rather than politely in the workshop.

- Battery is the clock — a drone that runs dry outside does not come home. It becomes a recovery mission, and recovery missions are how you lose the second drone.

- Weather-triggered malfunction — rain shorts, dust fouls delicate mechanisms. Sealed housings, artifacts and specialist hulls reduce the odds rather than remove them.

## THE DERELICT RECOVERY PUZZLE

Pre-collapse hulls and heavy machinery can't be pocketed. Each find is a three-way decision with a different risk profile:

| OPTION A | OPTION B | OPTION C |
| --- | --- | --- |
| FIELD HOTWIRE | HEAVY TOW | ON-SITE STRIP |


Haul a portable cell out, wake the frame in place, and drive it home under remote control. Fastest, and you inherit whatever condition it's in.

Send a high-torque tracked rig with a winch and crawl it back to the airlock. Slow, loud, and a fat target for the whole trip.

Cutting torch, take the high- tier components, abandon the frame. Safe, and you leave a landmark that says someone was here.

## SEC 06 THREAT ECOSYSTEM & BASE DEFENSE

The mutants are intelligent and they are patient. They are largely blind and light-sensitive, navigating by acoustic vibration, radio emission and thermal bloom — which means every choice that makes a drone effective also makes it audible.

- Trace — frequent sorties, unshielded transmissions and loud track motors accumulate a heat profile in a map sector. The bigger the hull, the heavier the trace it leaves.

- Escalation — high trace turns a sector into hunting ground: patrols thicken, then they start following cables and signals back toward the airlock.

- Siege state — once the bunker is pinpointed, packs mount a coordinated attack. The operator dumps power into perimeter fences, triggers pre- laid traps and issues direct fire orders to defensive chassis.

- Countermeasures as build incentive — sentry hulls, trap-laying utility bots, noise decoys and signal shielding all exist because trace exists. Defense is a reason to keep a machine home, and keeping a machine home is a cost.

## OPEN THREAD — ENEMY DROIDS

Mutants are the organic threat. A second, colder threat line is on the table: hostile machines — pre-collapse security units that reactivate when a salvage crew disturbs the wrong site. These would counter differently: immune to sound baiting, but vulnerable to EM, jamming and hacking, giving the player a reason to build an entirely separate loadout.


## SEC 07 ARTIFACTS

Artifacts are rare anomalies with a universal plug. Rather than being sized like ordinary modules — which would make a rare drop useless in the frame you happen to own — an artifact scales its effect to whatever it is socketed into: a small drone, a heavy builder, or the bunker's own breaker panel.

| ARTIFACT | IN A SMALL DRONE | IN A HEAVY CHASSIS | IN THE BUNKER PANEL |
| --- | --- | --- | --- |
| THERMAL SIPHON | Total immunity to cold | Radiates a 10 m heat | Cuts whole-base |
|   | drain, plus silent | ring, melting local | heating cost by 30%. |
|   | running. | permafrost. |   |
| NEURAL INTERFACE CORE | Crisp first-person | Direct piloting of a | Automation logic |
|   | manual control for | frame that normally | executes 200% faster |
|   | precision work. | needs scripts. | fleet-wide. |
| PHOTONIC CONVERTER | Continuous trickle | Offsets a fraction of the | Passive auxiliary power |
|   | charge from stray light | umbilical draw. | to the grid, day and |
|   | and radiation. |   | night. |

## DESIGN INTENT

Scaling instead of sizing keeps every artifact viable on every playthrough. A single lucky find should reshape a strategy — the player asks "where is this worth the most?", not "do I have the right slot?" Socketing one into yourself stays on the table as the rarest and most unsettling option.

## SEC 08 THE HUMAN SORTIE

The fail state is not a game-over screen. It is the game changing genre.


With the fleet destroyed or stranded beyond range, the operator suits up: an analog hazard suit with limited oxygen, fragile filters and a scratched visor, carrying a jumper battery on foot into the dark. Movement is slow. Defense is minimal. A life-support gauge ticks the entire time.

The objective is never combat — it is to reach one dead machine, wake it, and let it escort you home. Survive that and you resume operations, poorer and considerably more careful. Fail, and the bunker goes quiet.

## SEC 09 EXCAVATION & THE HARDENED BASE

Staying inside only means something if inside is worth staying in. This is what the player actually builds to earn that: tunnels instead of open ground, a rail line instead of a walk, and a perimeter that has to be paid for in full — nothing behind it is safe by default.

The bunker's footprint isn't fixed. A logistics sortie — typically a Goliath-class hull (Sec 03) fitted with a drill tool-arm in place of its usual winch — can be commanded to dig, but never piloted through rock in real time. The player marks the job instead: a straight route between two points, or a room's footprint as a width and depth on the command center's map, with a height capped by however far the drill reaches in a single pass. The sortie ties the job up for a set duration and reports back when it's clear — the same delegated-intent pattern as a standing order or a fabrication [URL 🔗](#page-0)

queue. Nobody steers a drill by hand.

## DIGGING DOESN'T DISCOVER GROUND

A tunnel can only be routed to a point already held on the surface network — a relay, a pylon, a founded FOB. Excavation hardens territory already earned the hard way; it is never a shortcut past scouting a band in the open first. Expansion still only ever pushes toward somewhere more dangerous, underground exactly as it does on the surface (Sec 10). [URL 🔗](#page-0)

## THE RAIL NETWORK

Every finished tunnel gets fitted with rail. Sorties sort cargo — batteries, rations, scrap, spare parts — between hubs on their own, so a growing


tunnel network is also a growing logistics system the player mostly stops thinking about, the same fading-tedium arc as everything else that gets automated over the course of a run.

The same rail carries the player. Because it runs underground, riding it is not going outside — the horror premise in Sec 01 is untouched no matter how far the network reaches. It's also, deliberately, the more reliable half of the game's two connectivity systems: wireless relays (Sec 04) are fast to set up and flexible but flaky by design, while a tunnel is slow and expensive to cut and then simply works — immune to weather, distance falloff, and random dropout. Committing to a tunnel means committing to a supply line that actually holds, at the cost of the drone-hours it takes to dig one. [URL 🔗](#page-0)

## WHAT CAN GO WRONG DOWN THERE

- Infrastructure has condition too. Rail segments and wiring conduits wear on the same 0–100% condition scale as mechanoid parts (Sec 03) — a neglected line starts short-circuiting and drawing power long before it fails outright, and scrap repairs it the same way it repairs a joint. [URL 🔗](#page-0)

- Noise travels underground too. Drilling and heavy rail traffic register on the same trace system as a loud surface hull (Sec 06). Tunnel recklessly close to a nest and it can find you from below as easily as from above. [URL 🔗](#page-0)

- Nothing behind a door is safe by default. Every point where the base meets open ground or unsealed tunnel — an airlock, a rail mouth, a wall worn thin — carries a standing chance of being forced once local trace runs high enough. Reinforced doors, wall plating and static defenses cut that chance; nothing removes it. It's the same mutants from Sec 06 finding an unsealed way in, not a new threat — the base is only ever as hardened as its worst-kept entrance. [URL 🔗](#page-0)

## PARKED — TERRAFORMING

An earlier draft of this section covered soil decontamination, atmospheric scrubbers and self-sustaining biomes as the mid-to-late- game build focus. It's cut for now. Excavation and defense serve the same design need — something concrete to construct with scrap and drone- hours that keeps paying off — while giving the escalating threat in Sec 06 a target the player can see and reinforce, rather than an invisible [URL 🔗](#page-0)


global stat. Terraforming stays on the table as a possible later addition, not a discarded one.

## SEC 10 WORLD SCALE & PACING

One commitment shapes the campaign: the world is finite and beatable. It is sized to be fixed, and the run ends when you fix it.

## A WORLD SMALL ENOUGH TO FIX

- Rectangular map, gated by range. The whole surface is one bounded vertical strip. The bunker sits near the south edge, at the bottom of the map, and every band of terrain further north is a step further from home.

- Danger and reward climb together, north. Five to eight bands stack upward from the bunker. The southernmost band is thin, safe salvage a blind quadruped can clear on day one; the northernmost is the richest pre-collapse caches, guarded by whatever the strongest mutant packs in the game are. There is no "easy region" hiding at the far edge and no "hard region" tucked next door — difficulty is literally altitude on the map.

- Expansion is directional, not free choice. Relay dishes and power pylons can only extend from ground you already hold outward to the band immediately north of it — never sideways to skip a band, never back to re-tread a cleared one. A forward operating base is, by construction, always the next-most-dangerous place you could have built it. This is the whole shape of progression: to get better rewards you must build toward worse odds, on purpose, one band at a time.

- The dead pylon line is the spine. It already runs out of the bunker in the prototype; it now runs north, and the substation at its far end is the first serious site in the contested band. Follow the pylons, find the reason they were built — a landmark chain is also how a blind drone navigates.

- Restoration is a tracked meter, not a vibe. The win state is a checklist the player can read on a bunker panel: each band's marquee nest cleared or permanently suppressed, a hardened perimeter (Sec 09) holding across [URL 🔗](#page-0)


every band you occupy, mutant nest density pushed below threshold. Completing it rolls credits.

- Escalating pressure prevents turtling. Each band's marquee nest grows on its own clock rather than one global stopwatch — left alone long enough, a nest gets loud and close enough to test the bunker's own doors (Sec 09). The safe play is to finish, not to stall. [URL 🔗](#page-0)

- Design budget: ~40 hours. Content is authored against a target run so the endgame arrives while the loop is still exciting.

| BAND 4 — FRONTIER | Richest caches and the apex threats gating the restoration checklist. |
| --- | --- |
| BAND 3 — CONTESTED | Derelict fields, hunting packs, weather at its most violent. |
| BAND 2 — BUFFER | First FOB sites, scattered patrols. Heavy hulls become worth the draw. |
| BAND 1 — APPROACH | Thin salvage, isolated scouts. Where the opening loadout earns its first camera. |
| HOME — BUNKER 14 | South edge. Airlock, workshop, first relay dish. Everything is measured as |
|   | distance from this point. |

FIG. 9.1 — NORTH–SOUTH MAP SECTION. THE PLAYER STARTS AT THE BOTTOM; EVERY RELAY PUSHED UPWARD TRADES SAFETY FOR WHAT'S WORTH TAKING.

## PARKED — OTHER BUNKERS

Rival operator-run bunkers (barter convoys, disposition that shifts on gifts and raids, loaned rescue drones) are cut from the current scope. The loop has to prove itself as one operator alone against the wasteland first; neighbors are a layer to add on top of a working game, not a way to make one work.


## SEC 11 OPEN QUESTIONS

## PROTOTYPE STATUS


A vertical slice runs in the Godot project: two drones — a blind quadruped hauler and a hovering CCD scout — with battery, signal, breadcrumb retrace, salvage, drone-to-drone rescue, the manual sortie, a sonar minimap and a full instrument panel. What is in the build, its tuned numbers, and the ordered plan for the rest live in the Roadmap & build log, which is kept current as things ship. [URL 🔗](https://claude.ai/code/artifact/f9fca094-d058-4bf0-a87c-b52ad67d8ad5)

## NEXT AREAS TO SPEC

Three candidates, in rough order of how much the rest depends on them: bunker UI and interaction design (what the panels physically are and how many there are), the tech and research tree (how books, blueprints and salvage convert into capability), and mutant AI behavior (sensing model, pack logic, siege choreography).

PROJECT OUTPOST — WORKING TITLE

REV. 0.5 · PRE-PRODUCTION
