# HOLLOW: shed the vessel

Progress is earned through combat. Waiting does not advance a realm or summon
a guardian. Enemy kills award realm points: husks 10, skitters 15, brutes 35,
and Fractured enemies add 100. Each realm starts with an empty point meter.

| Realm | Points to awaken guardian | Form / loss | World and play |
| --- | --- | --- | --- |
| The Whole / Arcane Garden | 750 | Complete human wizard, 100 base HP | Ordered garden walks; rest in the central sanctuary to heal |
| The Wound / Suffering Mire | 1300 | Muscle without skin, 85 base HP | Arteries, living eye-rocks, and telegraphed flesh eruptions |
| The Remains / Silent Ossuary | 1900 | Skull and bare skeleton, 70 base HP | Rib paths, tomb courts, bone creatures, and damaging fractures |
| The Hollow / Sea of Absence | 2500 | Magical soul, 55 base HP | Sparse memory islands, spectral creatures, lost shadow and fading cohesion |

The point target summons the current realm's guardian. Ordinary enemies stop
spawning during the encounter. Defeating the first three guardians sheds a layer
of the body and opens the next realm; a merchant waits beyond each guardian.
The fourth guardian frees the soul and ends the run in victory.
The clock measures elapsed play only: there is no timed descent or seven-minute boss.

Guardians have distinct difficulty and behavior: the Garden Warden fires a slow
six-bolt barrage, the Suffering Heart fires eight, the Ossuary King adds a
twelve-bolt burst after a dash, and the Hollow Guardian fires sixteen and
repositions after a barrage. Health is 360 / 540 / 760 / 1100.
All existing spells and ultimates remain available.

Each descent removes 15 maximum HP without undoing health upgrades. Current
health is clamped to the smaller vessel. Spells, relics, gold, position, ultimate
charge and loose pickups carry through. Previous enemies and projectiles are
cleared, and brief protection gives the player room to see the new form.
Descent waits for a paused Void Lightning cinematic to return safely.

The garden's sanctuary heals 2 HP every 2 seconds while standing within 150px
of the center outside a boss battle. Later realms lose this comfort.
Flesh and bone hazards mark the player's location, warn for 1.1 seconds,
then erupt briefly for 7 / 9 damage. Move away from the marked area.
Soul cohesion drains by 3 per second while still, or 0.8 while moving;
each ordinary kill restores 9. At zero, erasure causes 6 damage every 1.25 seconds.
The soul becomes translucent as cohesion drops. It has no physical shadow.
Footprints, darkness and quiet whispers reinforce the loss across the descent.

In a controlled moving-player pacing check, the four guardian gates were
reached in approximately 81–103 seconds apiece. The bot had invulnerability
for measurement and chose upgrades automatically; human pacing and difficulty
depend on movement, build, and collection. The targets are development values
in `scripts/managers/run_manager.gd`.

## Development controls

WASD / arrows move; magic casts automatically; Q uses charged Void Lightning.
In debug builds, **R cycles the realm immediately during active play**, including
skipping an active guardian. It resets realm points and threat timing, retains
the build, and wraps the soul back to the living realm. It does not advance
during a paused menu or cinematic. After victory or death, R restarts the run.
Development shortcuts cannot save high-score records.
K summons the current guardian, J damages it, G grants XP, H grants gold,
B opens a test merchant, L charges lightning, and V activates Surge.

## Artwork

The supplied flesh, bone and soul packs provide their terrain, creatures and
guardians. Their existing license notices remain in the original directories.
The garden floor is generated with the built-in image tool.

Four new player image requests and a unified four-form atlas request are in
progress. Generated individual sprites belong at `assets/realms/players/<realm>.png`.
The unified sheet belongs at `assets/realms/players/descent_atlas.png`, in a
2-by-2 grid: human, flesh, bone, soul. The engine isolates its white gutters with
the player cutout shader; source art remains intact.
When the image files are absent, animated in-engine player forms visibly depict
the same four bodies. Generated artwork automatically takes precedence when
installed. This fallback is authored in `scripts/visuals/player_form.gd`;
it is not a claim that the image service successfully generated the bitmap art.

Original artwork and historical installers are retained. Running an old
installer can restore older gameplay scripts. Preserve the supplied pack
directories when exporting or sharing this checkout.

## Checks and previews

```
godot --headless --path . --script tests/realm_smoke.gd -- --allow-pending-art
godot --headless --fixed-fps 60 --path . --script tests/realm_pacing.gd
godot --path . --script tests/realm_preview.gd
```

Remove `-- --allow-pending-art` to require generated player images in the smoke
check. The integration checks cover point gating, guardian defeats, menus,
health loss, build preservation, R cycling, soul cohesion and hazard telegraphs.
The preview script saves four gameplay images and four map overviews under
`assets/realms/previews/`, then closes automatically.
