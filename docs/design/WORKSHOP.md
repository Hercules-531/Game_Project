# Workshop transactions

M15: initial inventory is 80 scrap, 60 spare fuel minutes, four spare rations,
and sonar (100%), thermal (85%), cargo rack (100%) stock parts. These are
provisional balance values, separate from the life-support tanks.

Fitting consumes one stock part after socket/type/payload validation. Removing
returns that exact part's condition. Repair costs ceil(missing condition × 0.2)
scrap and restores 100%; a fully serviced part cannot be charged again.

One fabrication job runs at a time. Costs/durations live in recipes.tres: sonar
8/15s, thermal 10/20s, winch 16/35s, rack 6/10s, retrace 12/30s, Mule frame
40/120s, hover frame 55/150s. Payment occurs once at start. Jobs draw 0.6kW,
advance with the supplied-power fraction and stop during blackout/pause. There
is no offline progress. Completion credits exactly one item. CCD is deliberately
absent: the Mule's first camera must be discovered on the surface.

Hull assembly consumes a fabricated stock frame only when a physical workshop
bay is clear of walls, props, operator and other machines. It creates a uniquely
identified bare hull. The four staging positions respect the real shelf/pallet
geometry. Per-hull collision boxes cover the reviewed forms.

Fuel/ration loading transfers bounded quantities from inventory into life support;
full tanks reject the operation. Nothing creates replacement supplies for free.
Version 4 saves persist inventory and the paid queue, including remaining time.
Versions 1–3 migrate with the initial inventory and no job.
