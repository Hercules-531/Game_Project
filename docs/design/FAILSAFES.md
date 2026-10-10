# Freeze and retrace

M23 records positions every 0.5m while linked, capped at 2048 recent points per
machine. Link severance disarms manual throttle and cancels pending packets.
Without an operational retrace module the collision body freezes immediately.
With it, the machine steers through recorded points in reverse until radio returns.
It neither computes an untravelled shortcut nor teleports to base.

The next segment is checked with the actual body shape. Three blocked seconds
stop the attempt; depleted cells/jammed hardware stop movement. No new trail is
recorded while returning. Exhausting the remembered trail freezes the hull when
the network remains down. Link recovery stops the failsafe and requires deliberate
manual rearming. Docking clears field breadcrumbs.

Version 10 persists points, mode, cursor and blocked time. Transient radio input
queues remain discarded. Forecast modifiers will be persistent when M27 arrives.
