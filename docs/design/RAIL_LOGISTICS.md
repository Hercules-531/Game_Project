# M37 — Rail infrastructure and freight

M37a establishes the connected track/depot/power ledger. M37b adds automatic
replenishment and field service. Each is verified and committed separately.

Finished tunnel lining costs include rail, conduit and small hub platforms;
commissioning existing saved tunnels never charges their paid excavation again.
The chain uses its real excavated endpoints, remains underground and cannot
reach an unexcavated/unknown band. Wiring and service are independent of radio,
weather and random wireless loss; they still require finite grid energy.

A freight car costs 40 scrap and 120 grid-funded assembly seconds at 0.6kW.
Station lighting uses 0.02kW per connected hub. Portable 1kWh battery packs cost
8 scrap/45 fabrication seconds and start empty. Home charging is optional,
at most 1kW, and credits only energy paid in the current grid step. Pack mass
is 10kg regardless of charge; serial identity and charge persist. No energy is
created by manufacturing, transporting or reloading a pack. A field pack can
feed an owned pylon at 90% transfer efficiency, leaving the reusable empty pack.

The planned freight controller uses one 200kg car at 2m/s and 1.5kW, with only
funded motion. Replenishment rules name a source, destination, commodity,
minimum stock and batch limit. They transport scrap, rations, specific spare
parts, charged packs and empty packs for return/recharge. A car physically
approaches its source before loading; unavailable supply does not trap an empty
job. Cargo is debited once and credited once, retaining part/pack identity and
condition/charge. Full destination storage holds the cargo instead of discarding
or duplicating it. Disabling a rule never destroys already loaded goods.

Field depots remain distinct stores. The subsequent service integration will
let nearby machines unload resource cargo and use local scrap/parts at founded
FOBs over healthy wired links. Rare artifacts and research still require their
own explicit recovery/unload path. Values are tunable engineering choices;
human logistics/pacing assessment is not implied by accelerated scenarios.

M37b operating choices: a single 200kg car travels at 2m/s, with a 1.5kW
motor. Bulk stock uses one kilogram per transported unit; spare parts use their
catalogue mass and packs always weigh 10kg. The depot transfers a whole batch
when the car reaches the hub. Batch handling has no additional timed motor
phase. Up to one second of paid motor supply can remain in the car controller;
save/restore retains that exact reserve rather than minting another payment.

Rules are serviced in rotation. Source selection never loads remotely: an empty
car must arrive first, then recheck source stock and destination deficit. Turning
off a pending empty approach cancels it in place; loaded delivery continues.
Storage limits hold the complete delivery without loss (bulk 1,000,000, spares
2,000, packs 128). Returning packs can also hold a paid factory job at its output
limit; no pack is dropped to make room. The nominal 0.6kW factory remains on
while its output is blocked.

A founded, intact FOB within 8m of a deployed intact hull is its local service
bay when its underground wire is healthy. Fit/remove and repairs use that store;
home fabrication and life-support supplies retain the home store. Optional
per-depot auto-unload accepts resource cargo and stripped spare parts. Optional
auto-feed tops up the local pylon from stored packs at 90% efficiency. Charged
pack rules match at least 0.99kWh; return-empty rules match at most 1e-9kWh.
Archives, cameras and artifacts keep their existing explicit home unload path.
FOB handling is an immediate local transfer, not a home loader or hull teleport.
