# HOLLOW -- Milestone 5: Hollow Surge and Combat Polish

## Features
- Automatic Hollow Surge after collecting 40 kill energy. Normal kills +1, Fractured elites +5.
- Surge lasts 6 seconds, providing 55% increased spell damage, 30% faster casting, and 12% faster movement.
- Charged/powered-up HUD meter, animated halo, and activation announcement.
- On-hit floating numbers, death bursts, pickup sparkles, and boss entrance effects.
- Controlled camera shake for taking damage, Surge activation and boss entrance.
- Six original, synthesized WAV effects, using no third-party audio samples.
- Fixes the Milestone 4 boss bar stale reference bug (and clears the boss reference on death).
- Removes integer-division warnings from the arena tile rendering.

## Controls
- WASD/arrow keys: move.
- V (DEBUG ONLY): trigger Hollow Surge instantly. Debug actions disable high-score saves.
- Other debug keys remain G, H, B, N, K, J, M.

## Smoke tests
1. F5. Move and attack: see damage numbers, death bursts and hear quiet hit/kill sounds.
2. Collect XP/gold/hearts: sparkles and pickup sound.
3. Press V with no popup open: purple aura, Surge HUD countdown, noticeably faster spells.
4. Press G, H, B: spells and the shop must still work. Surge timer pauses in menus.
5. Press K and J x4: boss defeat and victory must not crash. Restart with R.
6. Let normal enemies die for 40 energy: Surge should also activate naturally.
7. Non-debug runs save high score; using V or any other debug key does not.

## Project edits
The script backs up the previously existing files to .hollow_backup_milestone5_... .
New scripts: scripts/systems/combat_fx.gd, camera_shake.gd, sfx_manager.gd.
New WAV files: assets/sounds/generated/m5_*.wav.
Scene updates: scenes/main.tscn, scenes/player/player.tscn, scenes/ui/hud.tscn.
It preserves the existing player/enemy/boss mechanics, upgrade selections, score and shop logic.

## Tips
- Synthesized effects are deliberately subtle. Adjust volume_db in sfx_manager.gd.
- If you edit the original game scripts, version the project with Git before further upgrades.
- This installer targets the generated Milestones 1-4 baseline; review conflicts before using with heavily modified code.
