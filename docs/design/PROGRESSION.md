# M31 — recovered knowledge and research

The GDD leaves the research tree unspecified. Under the user's authorization to continue every checkpoint, these are documented engineering choices.

Knowledge is physical cargo. A powered salvage machine must retrieve a manual or blueprint, carry its 1kg data crate and unload through the sealed loader/exterior gantry. No proximity unlock, scrap-for-universal-XP or fabricated first CCD recipe. Salvaged machinery and existing fittings stay usable without research; manufacturing advanced hulls/modules requires its topic.

Verified art is the supplied PSX `props/book.glb` and matching `book_albedo.png`, on the existing PSX metal data crate. Its albedo import is limited to 64px/no mipmaps and bound to the stable nearest PSX material. Blueprints reuse this physical sealed archive form; no missing guide or invented texture is assumed.

| Topic | Physical archive (world E/Z) | Prerequisite | Scrap / powered seconds | Capability |
| --- | --- | --- | --- | --- |
| Field recovery | E10 / -72 | none | 20 / 180 | tracked hull, heavy winch, scrapers, sealed circuits |
| Field network | E4 / -98 | recovery | 24 / 240 | relay dishes, pylons and FOB construction (M32) |
| Perimeter defense | E-9 / -145 | network | 32 / 300 | defense fittings and infrastructure (M33) |
| Heavy engineering | E12 / -252, substation | network | 50 / 360 | Goliath, tender, biped, coupler, solar and prefab winch |
| Excavation | E-12 / -335 | heavy engineering | 50 / 480 | drill and delegated underground jobs (M36) |
| Multispectrum optics | E20 / -445 | heavy engineering | 60 / 600 | Tier 2+ optics (M35) |

One research queue consumes 0.35kW from the bunker grid, paid in fresh one-second energy steps. Scrap is charged once; blackout/pause holds progress; prerequisites and recovered knowledge are required. The manual is retained, with completion persistent and no repeat refund/unlock. UI names/requirements guide the player; it does not reveal unsurveyed archive coordinates.

Opening recipes remain sonar, thermal, winch, rack, retrace, jumper, torch, signal shield and the two basic hulls. New games start with no advanced research. Existing pre-M31 saves retain the engineering capabilities that were already available, while new network/defense/optics remain earned. An in-flight pre-M31 advanced fabrication job is completed normally, not charged again.

The archives' locations establish dependencies; the later individual campaign-band checkpoints add authored routes, risk and reward around them. Research durations are tuning assumptions, not validation of a 40-hour campaign.
