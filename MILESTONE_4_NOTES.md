# HOLLOW - Milestone 4: Final Boss and Complete Run

## Included

- A seven-minute boss trigger using gameplay time, not wall-clock time.
- Hollow Guardian with two alternating attacks (telegraphed radial barrage and telegraphed dash).
- The boss counts as an `enemies`-group target; all three existing spells damage it.
- A boss health bar at the top of the screen.
- Fully functional victory/defeat overlay with restart and quit buttons.
- Local high score stored in Godot's `user://hollow_best_score.cfg` using ConfigFile.
- Results include score, time, normal enemy kills, level, and gold remaining.
- Debug runs never overwrite the real high score.

## Controls

- WASD / arrow keys: move.
- R on end screen: restart.
- G (debug): gain XP for next level.
- H (debug): gain 30 gold.
- B (debug): open shop.
- N (debug): add one minute to run clock.
- K (debug): start boss encounter immediately.
- J (debug): damage current boss by 400 (four presses to win from full HP).
- M (debug): finish run with defeat immediately.

## Recommended tests

1. F5: verify normal survival, XP and merchant still work.
2. K: enemies should disappear and the purple Guardian should spawn near the player.
3. Watch for the circular barrage telegraph and directional charge line.
4. The boss should receive damage from Soul Needle, Void Pulse and Orbiting Shade.
5. J x4: boss should die; victory overlay, score bonus and restart should work.
6. M on a different run: defeat overlay should work.
7. Test a normal non-debug run to completion. Its high score should persist after restarting.

## Notes

- The Godot editor must be closed when installing.
- Modified files are copied into a `.hollow_backup_milestone4_*` folder.
- The HUD bottom debug hint is updated to include K/J/M.
- Rendering uses placeholder polygons and colored circles. Art and audio come later.
- The boss enters at 07:00 on the run clock. A win may take 30-90 seconds afterwards.
