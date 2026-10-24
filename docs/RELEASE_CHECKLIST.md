# Release acceptance checklist

M44 local technical verification passed. This is a playtest candidate, not
completed human acceptance or a public release signoff.

| Requirement | Verification and current status |
| --- | --- |
| New Game and Continue in exported executable | Passed: opt-in startup routes to `release_flow.tscn`, which runs the real menu/session and isolated save service. |
| Pause, settings, key rebinding and audio | Passed: frozen simulation, visible settings, persisted input/volume, real bus mute and PCM/director; hardware run also passed live mixer output. |
| Fleet, world and infrastructure persistence | Passed: probe rescues/returns a zero-cell drone, saves finite state and a provisioned tunnel/depot, then verifies Continue. M43 separately covers live work/travel costs. |
| Recovery loop | Actual jumper spends finite energy and the timed loader docks the rescued hull; field arrival is a declared fixture, not a fully driven expedition. M43a and the recovery suites cover physical field loops. |
| Restoration and credits | Probe supplies checklist prerequisites, then verifies actual completion, credits/pause and persisted seen state without automatic replay. M43c separately verifies paid final repair. |
| No development bridge in export | Passed: runtime probes reject the helper and editor build. |
| Missing imports, assets and shader errors | Import/export and final runtime logs passed; actual D3D12/Forward+ framebuffer inspected. |
| PSX presentation | Passed hardware 640×480 capture. Shader defaults retain stable UVs/snapping off; materials assert verified Textures/ paths, ≤64px and no mips, with nearest sampling. Softer compositor remains unchanged. |
| Audio shutdown | Passed four repeated quick-exit probes and the headless/hardware acceptance flows after stopping playback and draining cleanup for 0.1s. Verifier now rejects leak warnings. |
| Notices with executable | Packaging includes THIRD_PARTY_NOTICES.md and licenses/ for Godot/bundled libraries, Phantom Camera, Torment and SBS. PSX terms deferred by user; unverified. |
| Hosted test/export CI | M43c run 40103797643 passed 247 / 3,269, export and artifact upload. Final M44 source run is checked after pushing the checkpoint; see delivery status. |
| Human readability, tension and control feedback | Pending; no human session recorded. |
| Approximately 40 hours to restoration | Pending a complete recorded human campaign. Accelerated fixtures do not prove this. |

Run `tools/verify.ps1 -Export`, then run the exported acceptance scene without
`--headless` to exercise actual rendering/audio. Both use the dedicated
`user://tests/release_probe/` slot. The `--verify-release` flag selects isolated
settings before the settings autoload reads or writes anything. Default and
playtest saves/settings must remain unchanged during these probes.

Rebuild `builds/ProjectOutpost-Playtest.zip` with `tools/package_playtest.ps1`
after the final checks pass. Human sessions use **Start-Playtest.cmd**, which
selects the separate playtest profile. See [playtest report](PLAYTEST_REPORT.md).
