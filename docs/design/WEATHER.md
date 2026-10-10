# Weather schedule

The opening has a five-minute frozen overcast preparation window. Thereafter
the five global GDD conditions have seeded 20–30 minute windows, with no
immediate repeats. The terminal forecasts the next two windows. Geothermal
pockets are spatial features, not a global sky condition.

Seed, active condition, remaining time and both forecasts persist in version 15.
These durations are initial balance choices under the user's current authority.
M27a establishes the schedule; M27b–g implement the separate hazard/tradeoff rows,
each with its own verification and commit. Creature responses complete in M29.

M27b: the optional bunker collector costs 24 scrap, takes 60 seconds of paid
0.6 kW work and produces 1 kW in baseline conditions. Crisp sunlight multiplies
it by 1.75. A physical ray to the sun rejects blocked collectors. Power enters
the existing finite grid, so home charging is funded rather than assigned
directly to a drone. Construction, installation and its switch persist in v16.
The collector uses custom PSX-metal geometry; no new bitmap was added.

M27c: smog reduces radio range to 60%, adds 1.5 seconds to command latency,
raises seeded dropout chance to 8% per field cycle, adds 65% CCD interference,
and limits the exterior optical camera to 35m in green ion fog. IR remains
usable. The sealed bunker stays clear. Creature sensory range becomes 50%
when M29 integrates sensing. These derived values reset on clear weather and
reapply when restoring the saved condition.

M27d: ash doubles field wear and the existing condition-band fault chance,
clamped to 100%. Pristine parts retain their normal fault immunity. Thirty
cumulative ash seconds uncover a 30kg / 24-scrap cache at E6, N45. Discovery,
physical hauling and once-only delivery persist in v17; earlier saves migrate
with that cache still buried. Dust fog is limited to the exterior environment.

M27e: external exposure is sampled once per 60 field seconds: rain cell shorts
12%, ash lens/bearing fouling 8%. Faults last eight seconds. These environmental
events can affect pristine parts independently of intrinsic condition faults.
Tracked housings reduce exposure risk by 25%; sealed utility housings reduce
it by 60% when fitted (hardware arrives in M28). Risk never becomes zero.
Rain adds 0.003 armor wear/second and doubles surface suit-filter consumption.
The E-9/N54 hotspot has a 5m radius; contamination adds up to 0.5kW draw and
filter drain. Rain washes 0.05 percentage points/second off its persistent
contamination. Rain streaks are PSX-metal geometry, not a new bitmap. Patrol
shelter integrates in M29. Exposure RNG/cycles/contamination persist in v18.

M27f: the existing E9/N38 vent has a 6m cold-free pocket. Motors/modules still
consume power. Within 3m unstable footing reduces speed to 55%; within 2.5m,
each cumulative minute of exposure causes five armor points and an eight-second
joint jam. Three amber PSX-metal stakes mark the inner hazard. Exposure persists
in v19, preventing save/reload or brief exits from resetting the risk.
