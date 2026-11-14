# Sound Library

Godot path root: `res://Audio/` (all paths below are relative to `Audio/`).
14 unique sounds, all MP3. Last updated: 2026-11-14.

Each sound was checked by analysing its waveform and spectrum: loudness envelope, frequency bands, rhythm and pitch. Filenames were not the only evidence. Every copy decodes without errors and is byte-identical to the upload. Nothing was re-encoded.

## Index

| File | Category | Character / Purpose | Format | Duration |
|---|---|---|---|---|
| `Characters/Goblin/Attacking/daviddumaisaudio-small-monster-attack-195712.mp3` | Character – Attacking | Goblin: short voiced attack snarl (~195 Hz, mid-range, not deep) | MP3 44.1 kHz stereo 256 kbps | 0.76 s |
| `Characters/Goblin/Death/freesound_community-goblin-death-6729.mp3` | Character – Death | Goblin: short high-pitched death squeal | MP3 24 kHz stereo 160 kbps | 1.73 s |
| `Characters/Goblin/Other/phatphrogstudio-monster-goblin-voice-excited-enemy-spotted-519428.mp3` | Character – Other (alert) | Goblin: excited, raspy chatter. Plays when a goblin spots the player or becomes aggressive | MP3 44.1 kHz stereo 256 kbps | 3.74 s |
| `Characters/Big_Goblin/Walking/bannythecoolio-gentoix27s-bon-footsteps-loop-walk-424387.mp3` | Character – Walking | Big Goblin: heavy, low thudding steps (almost all energy under 500 Hz, ~0.7 s per step). Loops. Would also work for the Knight | MP3 44.1 kHz stereo 256 kbps | 5.49 s |
| `Characters/Knight/Attacking/dragon-studio-sword-clashhit-393837.mp3` | Character – Attacking | Knight: metallic sword clash / hit with a ringing tail | MP3 44.1 kHz stereo 256 kbps | 1.10 s |
| `Characters/Knight/Attacking/dragon-studio-sword-slice-393847.mp3` | Character – Attacking | Knight: sword swing / slice (variant A) | MP3 44.1 kHz stereo 256 kbps | 2.19 s |
| `Characters/Knight/Attacking/dragon-studio-sword-slice-2-393845.mp3` | Character – Attacking | Knight: sword swing / slice (variant B, louder and brighter) | MP3 44.1 kHz stereo 256 kbps | 2.19 s |
| `Characters/Knight/Walking/freesound_community-footsteps-in-forest-83834.mp3` | Character – Walking | Knight: clean footsteps on leaves and twigs (forest floor) | MP3 24 kHz stereo 160 kbps | 4.75 s |
| `Music/Main_Menu/white_records-dark-gladiator-epic-background-music-for-video-stories-37-second-490015.mp3` | Music – Main Menu | Dark, epic orchestral track. Builds up, holds, then fades out (does not loop seamlessly) | MP3 44.1 kHz stereo 256 kbps | 37.38 s |
| `Music/Other/kaazoom-embers-on-the-flagstone-30-sec-edit-medieval-tavern-rpg-game-music-616108.mp3` | Music – Other | Medieval tavern tune at a steady level. Could suit Loading, a tavern/hub, or calm gameplay. Placement not decided | MP3 48 kHz stereo 256 kbps | 29.98 s |
| `Environment/Forest/photos-walking-in-a-forest-395345.mp3` | Environment – Forest | Forest field recording: footsteps over a constant rustle/bird background. Use as ambience, not as a character footstep | MP3 48 kHz mono 256 kbps | 23.45 s |
| `UI/Buttons/u_u4pf5h7zip-click-345983.mp3` | UI – Buttons | Short, crisp button click | MP3 44.1 kHz stereo 256 kbps | 0.16 s |
| `Other/prmodrai-damage-blowhole-402072.mp3` | Other (unassigned) | Generic punchy hit / damage impact, not vocal. Could be Taking_Damage for any character | MP3 48 kHz stereo 256 kbps | 1.03 s |
| `Other/dragon-studio-heavy-boulder-thud-515257.mp3` | Other (unassigned) | Very heavy, deep ground impact (77% sub-bass). Could be a Big Goblin slam attack or a body hitting the ground on death | MP3 48 kHz stereo 256 kbps | 2.11 s |

## Summary

- **Goblin:** attack snarl, death squeal, alert chatter ("enemy spotted").
- **Big Goblin:** heavy walking loop only. No vocals yet.
- **Knight:** 3 sword sounds (clash, 2 slices) and forest-floor footsteps.
- **Main menu and loading music:** 1 main menu track (dark gladiator). No loading track has been chosen. The tavern tune is a candidate.
- **Other music:** 1 medieval tavern tune.
- **Environment / UI:** 1 forest ambience, 1 button click.
- **Unassigned (`Other/`):** generic damage hit, heavy boulder thud.

## Missing categories

- Goblin: Idle, Walking, Taking_Damage
- Big Goblin: Idle, Attacking, Taking_Damage, Death, and any deep/heavy vocals
- Knight: Idle, Taking_Damage, Other (armour, vocals, jump etc.)
- Music: Loading, Gameplay, Forest, Dungeon
- Environment: Dungeon, Graveyard
- UI: Menus, Notifications

## Duplicates not copied

These uploads are byte-identical to a file already in the library, so only one copy was kept:
- `…goblin-death-6729` (4 uploads, including `_1` and `- Copy`)
- `…goblin-voice-excited-enemy-spotted-519428` (4 uploads)
- `…bon-footsteps-loop-walk-424387` (3 uploads)
- `…footsteps-in-forest-83834`, `…walking-in-a-forest-395345`, `…click-345983` (2 uploads each)
- `…dark-gladiator…490015`, `…embers-on-the-flagstone…616108` (uploaded twice, once in each message)

## Notes for Godot / HTML5 (itch.io)

- Folder and file names have no spaces. Web exports are case-sensitive, so reference paths exactly as written here.
- MP3 imports natively in Godot 4 as AudioStreamMP3 and works in HTML5 exports. To make a file loop, enable **Loop** in that file's Import settings. This suits the footsteps loop, the forest ambience and the music.
- The original filenames were kept for traceability. Only the upload ID prefix was removed.
- Two sources, `damage-blowhole` and `boulder-thud`, already decode slightly above 0 dBFS (+3 dB). That is how they were supplied and they were left unaltered. Lower their volume in Godot if they clip.
