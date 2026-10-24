# Campaign playtest report

## Acceptance status

The automated opening scenario is implemented. Human feedback and accumulated
campaign playtime are **pending**. No human session has been recorded, and the
GDD's approximately 40-hour restoration target has not been validated.
Automation does not close M43a–c's human acceptance requirements.

| Pass | Automated evidence | Human evidence |
| --- | --- | --- |
| M43a: opening | Physical salvage/camera trips, paid costs and reload; see [checkpoint](verification/M43a.md) | Pending |
| M43b: expansion/siege | Live paid construction, convoy power loss/reload, defended work and siege recovery; see [checkpoint](verification/M43b.md) | Pending |
| M43c: underground/completion | Integrated campaign pass pending | Pending |

## Opening scenario

The GUT scenario starts a new game in a unique `user://tests/` save slot. It
holds sunlight and runs at 4x simulation speed, with the actual command delay,
drone body movement, loader duration, energy, wear, radio and threats active.
It drives the blind Mule to scrap, returns and unloads, then recovers the CCD
case, returns and fits the actual recovered part in the workshop. Carrying the
case alone does not grant vision, and the CCD cannot be fabricated as a shortcut.
Save/Continue must preserve the installed camera, scrap, battery and condition.

This directed route tests mechanics and resource accounting. It excludes the
time a person spends learning controls, interpreting sonar, planning routes and
responding to changing weather. Its simulation seconds are not first-hour or
whole-campaign pacing measurements. No balance constants were changed from
these measurements alone.

The separate 3,600-second life-support calculation leaves 60 fuel and 6 rations
from 120 and 8, with powered O2/heating maintained. Only life support is advanced
in that calculation; it does not demonstrate that waiting an hour is safe from
weather, growth, trace, attacks or other world systems.

## Running a human session

After `tools/verify.ps1 -Export` passes, run `tools/package_playtest.ps1`.
Extract `builds/ProjectOutpost-Playtest.zip` and launch **Start-Playtest.cmd**.
The launcher selects `user://playtest/save.json` and
`user://playtest/settings.json`; the regular outpost save/settings stay separate.
Launching the executable directly uses the regular profile. Existing playtest
progress is retained, so choose Continue when resuming a recorded session.

Record the build manifest checksums, session start/end, active human playtime,
milestones reached, deaths/reloads and assistance used. For the opening, record
whether the blind feed, loader, first salvage delivery, camera fitting and
recovery options were understandable. Record readability and control problems
at normal speed, and capture resources before/after each sortie.

For expansion, record relay outages, field charging, convoy failures, trace and
siege recovery. For underground play, record actual excavation wait/cost,
freight/passenger rail use, maintenance, ingress and restoration progress.
Compare cumulative human time to the GDD target only after a complete campaign.
The local candidate is for validation; final release acceptance is still pending.
