# Bow Weapon — Asset Attributions

Rebound of Ruins · bow-and-arrow weapon system · sourced and verified 15 November 2026

Only assets downloaded from outside the project for the bow system are listed as external assets. Licences were read on each asset's original page; the CC0 status of the 3D models is also confirmed by the `LICENSE` file inside the download.

---

## 1. Bow and arrow models

| Field | Details |
|---|---|
| Asset name | Bow, arrow, quiver |
| Category | 3D models (bow, arrow) |
| Creator | mess110 |
| Original asset page | https://opengameart.org/node/112467 |
| Downloaded file | `bow.tar_3.gz` → `bow.glb`, `arrow.glb` (`quiver.glb` and `bow.blend` not used) |
| Project location | `assets/weapons/bow_mess110/` (the pack's `LICENSE` file is kept alongside) |
| Exact licence | CC0 1.0 Universal (Public Domain Dedication). The bundled `LICENSE` file reads "Public domain — made by mess110". |
| Licence URL | https://creativecommons.org/publicdomain/zero/1.0/ |
| Attribution required | No (credited here voluntarily) |
| Modification permitted | Yes |
| Commercial use permitted | Yes |
| Modifications made | Files are unmodified. In Godot: the held bow is turned 180° so the string faces the archer, scaled non-uniformly (0.75 × 0.34 × 0.34) so its limbs read from the top-down camera, and canted across the body while carried; 0.36 scale on the pickup; arrow scaled non-uniformly (0.55 × 0.55 × 0.29); fire arrows get an orange additive overlay material at runtime; shadow casting disabled on the held bow and nocked arrow. The bow's own draw animation drives the string pull. |

## 2. Bow release and arrow flight sounds

| Field | Details |
|---|---|
| Asset name | Battle Sound Effects |
| Category | Sound effects |
| Creator | artisticdude (submitted to OpenGameArt by Ogrebane) |
| Original asset page | https://opengameart.org/content/battle-sound-effects |
| Downloaded file | `battle_sound_effects_0.zip` → `Bow.wav` (bowstring release), `swish_2.wav` (arrow flight) |
| Project location | `Audio/Weapons/Bow/` |
| Exact licence | Offered under CC0, CC-BY 3.0, CC-BY-SA 3.0, GPL 3.0 and GPL 2.0. Used here under **CC0**. |
| Licence URL | https://creativecommons.org/publicdomain/zero/1.0/ |
| Attribution required | No under CC0 (credited here voluntarily) |
| Modification permitted | Yes |
| Commercial use permitted | Yes |
| Modifications made | Files are unmodified. Volume and a small random pitch variation are applied at playback. |

---

## Existing project sounds reused (not externally sourced for this feature)

These were already in the project and are credited in `CREDITS.md`:

| Use in bow system | File |
|---|---|
| Arrow hitting an enemy | `Audio/Other/prmodrai-damage-blowhole-402072.mp3` |
| Arrow hitting ground or walls (pitched up, quiet) | `Audio/Other/dragon-studio-heavy-boulder-thud-515257.mp3` |
| Pickup, weapon switch, out-of-arrows click | `Audio/UI/Buttons/u_u4pf5h7zip-click-345983.mp3` |

## Candidates considered but not used

- **Archery Set** by yd (OpenGameArt, CC0) — only available as a `.blend` file; the mess110 pack was chosen for its ready GLB files and flat colours that match the game's blocky style.
- **Impact Sounds** by Kenney (CC0) — its download link only works inside a browser session, so it was not downloaded; existing project sounds cover impacts instead.

No asset in the bow system was generated, synthesised or AI-created.
