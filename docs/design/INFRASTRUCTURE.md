# M39 — Infrastructure condition and maintenance

Engineering choices under the continuing authorization:

- Rails and conduits have separate 0–100 condition. Reuse the approved part
  bands: ≤20 gives 35% efficiency/50% cycle fault risk, >20–80 gives normal/
  10%, >80 gives 120%/no condition fault. Fresh rail retains the existing 2m/s
  car speed; normal rail is 2/1.2 and low-condition rail 2×0.35/1.2 m/s.
  Zero condition is a permanent outage until service.
- Rail wear is 0.001 points per actual metre × (1 + payload/200kg). The rider
  counts as 80kg; empty approaches still wear rail. Fault cycles count actual
  powered travel seconds, not frames. A rail jam lasts eight simulation seconds.
- Energized conduit ages 0.00025 points per paid second plus 0.5 points per
  paid kWh carried. Its efficiency is the band efficiency/1.2. Root demand
  includes every downstream loss before crediting useful energy. Worn wire
  therefore draws extra power before it fails. Each 60 energized seconds uses
  the same band fault chance; a short trips downstream services for eight
  seconds while drawing 2kW from the healthy upstream supply. Isolating a wire
  for maintenance stops its short draw. Weather/radio never cause these faults.
  A source-port breaker can also isolate unused or damaged conduit before a
  repair hull is ready, so a short need not drain the base indefinitely. This
  switch persists and must be reconnected explicitly after service.
- Track and wire connectivity are distinct. A rail jam halts traffic while
  healthy wiring can keep station lights and depot services running. A wire
  outage stops downstream grid-fed service and traffic. Paid car reserve is
  retained, never duplicated or discarded by a fault/reload.
- A maintenance assignment reserves an actual torch-equipped hull at the source
  hub. Home accepts a hull in the workshop or exterior cradle; field work needs
  a founded intact FOB, a hull within 8m and healthy upstream wiring. The hull
  still needs normal power. An active assignment blocks other work/transfer/
  fitting and isolates the component; a held job can resume after resupply.
- Scrap is charged once from that hub's actual stock: ceil((100-condition)×0.2),
  at least one for clearing a fault. Base time is 15 + 0.5×missing condition +
  0.05×segment metres; torch efficiency scales work. A 1kW wired service port
  must pay each work step freshly. Cancellation/loss gives no refund. Completion
  restores 100 and clears the component's fault/cycle. Independent jobs may run
  in parallel; one hull and one component cannot be assigned twice.
- Save v33 retains condition, clocks, faults, RNG and already-paid jobs. Older
  saves retain their rail condition and migrate with intact conduits. Simulation
  restore never counts old movement again or creates service credits.

Files: infrastructure_condition.gd (bands/wear/power/faults), maintenance_job.gd
(quotes/validation), maintenance_panel.gd, common work reservations, rail/freight/
passenger power and movement integration, save schema and infrastructure tests.
Use only existing verified PSX surfaces for any line indicators.

Verification: exact boundaries; distance/load wear; fresh vs worn power debit;
partial/blackout payment; genuine slow/jammed/open-line movement; independent
wire vs track behavior; seeded cycle partitioning; local scrap and reserved hull;
held/lost/cancelled work; repaired service; reload of trips/faults/jobs; old saves;
640×480 terminal and live visual checks. Rates remain tunable; accelerated tests
do not establish the campaign's human maintenance burden.
