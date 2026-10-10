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
