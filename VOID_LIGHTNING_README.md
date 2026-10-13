# HOLLOW - Void Lightning Ultimate

## Gameplay
- Earn +1 Void Lightning energy per kill (separate from automatic Hollow Surge).
- At 25/25, press Q to activate manually, while enemies are alive.
- The game pauses for the cinematic: enemies, spawns, boss behavior, and timer freeze.
- The hero vanishes into a bright cyan lightning orb, zips between every CURRENTLY ALIVE enemy, and shakes the camera with every hit.
- Damage per target: Husk/Skitter/Brute 80, Fractured 110, Guardian 180. Damage is amplified during active Hollow Surge.
- After the last hit, the orb returns to the exact origin, the hero reappears, and the run resumes.
- 0.65s return invulnerability prevents unfair instant contact deaths.
- Enemies can die and drop loot during the sequence; XP collection resumes once unpaused.
- Debug shortcut: L fills the meter (debug runs cannot set records). Q always works in normal runs.
- Using Q normally does NOT disable high-score tracking.

## Files
- Added: scripts/systems/void_lightning.gd
- Added: assets/sounds/generated/void_lightning_charge.wav
- Added: assets/sounds/generated/void_lightning_impact.wav
- Modified: scenes/main.tscn (one new script resource + one new node)
- Existing player, enemy, boss, spell, run manager and art files are NOT modified.
- Backup of original main scene in .hollow_backup_void_lightning_... .

## Test
1. Press F5 and L (running from editor) to charge instantly.
2. Press Q. Game clock and enemies should freeze. Watch the glowing orb chain across enemies and shake the camera at each strike.
3. Verify it returns to the exact starting point and ordinary combat resumes.
4. Press K (debug summon boss), then L and Q to test the boss hit.
5. Repeat while Hollow Surge is active (V for testing) and verify no crash.
6. Let enemies die normally to fill the meter; Q works without debug mode.

Tip: This version targets all CURRENTLY LIVING enemies, up to the 65-unit arena cap. Long chains can take several seconds. Reduce enemy density later if the full-map camera travel is too intense.
